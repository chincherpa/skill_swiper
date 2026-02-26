import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/skill.dart';
import '../../../services/supabase_service.dart';
import '../../../models/profile.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _service = SupabaseService();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _saving = false;

  // Step 1: Personal info
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  Uint8List? _avatarBytes;
  String? _avatarUrl;

  // Step 2: Location
  double? _latitude;
  double? _longitude;
  bool _locationLoading = false;
  String? _locationLabel;
  int _radiusKm = 10;

  // Step 3: Skills
  List<Skill> _skillCatalog = [];
  final List<_SelectedSkill> _selectedSkills = [];

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _loadSkillCatalog();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadSkillCatalog() async {
    try {
      final catalog = await _service.getSkillCatalog();
      setState(() => _skillCatalog = catalog);
    } catch (e) {
      // Will retry when user reaches step 3
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _avatarBytes = bytes);
    }
  }

  Future<void> _requestLocation() async {
    setState(() => _locationLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Standort-Berechtigung wurde verweigert')),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationLabel =
            '${position.latitude.toStringAsFixed(2)}°, ${position.longitude.toStringAsFixed(2)}°';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Standort konnte nicht ermittelt werden: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _saveProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveProfile() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Füge mindestens einen Skill hinzu')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = _service.currentUserId!;

      // Upload avatar if selected
      if (_avatarBytes != null) {
        _avatarUrl = await _service.uploadAvatar(userId, _avatarBytes!);
      }

      // Save profile
      final now = DateTime.now();
      await _service.upsertProfile(Profile(
        id: userId,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        avatarUrl: _avatarUrl,
        latitude: _latitude,
        longitude: _longitude,
        radiusKm: _radiusKm,
        createdAt: now,
        updatedAt: now,
      ));

      // Save skills
      for (final skill in _selectedSkills) {
        await _service.addUserSkill(
          skillId: skill.skill.id,
          description: skill.description,
        );
      }

      if (mounted) context.go('/swipe');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSkillPickerDialog() async {
    if (_skillCatalog.isEmpty) {
      await _loadSkillCatalog();
      if (_skillCatalog.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Skill-Katalog konnte nicht geladen werden')),
          );
        }
        return;
      }
    }

    // Filter out already selected skills
    final selectedIds = _selectedSkills.map((s) => s.skill.id).toSet();
    final available =
        _skillCatalog.where((s) => !selectedIds.contains(s.id)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle verfügbaren Skills bereits hinzugefügt')),
        );
      }
      return;
    }

    final descController = TextEditingController();
    Skill? chosen;

    final result = await showDialog<_SelectedSkill>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Group by category
            final categories = <String, List<Skill>>{};
            for (final s in available) {
              categories.putIfAbsent(s.category, () => []).add(s);
            }
            final sortedCategories = categories.keys.toList()..sort();

            return AlertDialog(
              title: const Text('Skill hinzufügen'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chosen == null)
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: sortedCategories.map((category) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children:
                                      categories[category]!.map((skill) {
                                    return ActionChip(
                                      label: Text(skill.name),
                                      onPressed: () {
                                        setDialogState(
                                            () => chosen = skill);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    else ...[
                      Chip(
                        label: Text(chosen!.name),
                        onDeleted: () =>
                            setDialogState(() => chosen = null),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Beschreibung',
                          hintText:
                              'z.B. Zeige dir in 2 Stunden die Basics...',
                        ),
                        maxLength: 200,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen'),
                ),
                if (chosen != null)
                  ElevatedButton(
                    onPressed: descController.text.trim().isNotEmpty
                        ? () => Navigator.pop(
                            ctx,
                            _SelectedSkill(
                              skill: chosen!,
                              description: descController.text.trim(),
                            ))
                        : null,
                    child: const Text('Hinzufügen'),
                  ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedSkills.add(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schritt ${_currentStep + 1} von 3'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: AppColors.background,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalInfoStep(),
                _buildLocationStep(),
                _buildSkillsStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Über dich',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.background,
                backgroundImage:
                    _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null
                    ? const Icon(Icons.camera_alt,
                        size: 32, color: AppColors.textSecondary)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Wie möchtest du genannt werden?',
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: 'Bio',
              hintText: 'Erzähl etwas über dich...',
            ),
            maxLength: 300,
            maxLines: 3,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed:
                _nameController.text.trim().isNotEmpty ? _nextStep : null,
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dein Standort',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Damit wir dir Leute in deiner Nähe zeigen können.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _locationLoading ? null : _requestLocation,
            icon: _locationLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_locationLabel ?? 'Standort freigeben'),
          ),
          if (_locationLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.swipeRight, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Standort erfasst',
                  style: TextStyle(
                      color: AppColors.swipeRight,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Umkreis: $_radiusKm km',
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _radiusKm.toDouble(),
            min: 5,
            max: 50,
            divisions: 3,
            label: '$_radiusKm km',
            onChanged: (value) {
              setState(() => _radiusKm = value.round());
            },
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('5 km'),
              Text('10 km'),
              Text('25 km'),
              Text('50 km'),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _nextStep,
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Deine Skills',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Was kannst du anderen beibringen?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedSkills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 64,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Füge mindestens einen Skill hinzu',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _selectedSkills.length,
                    itemBuilder: (context, index) {
                      final s = _selectedSkills[index];
                      return Card(
                        child: ListTile(
                          title: Text(s.skill.name),
                          subtitle: Text(s.description),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(
                                  () => _selectedSkills.removeAt(index));
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedSkills.length < 10)
            OutlinedButton.icon(
              onPressed: _showSkillPickerDialog,
              icon: const Icon(Icons.add),
              label: const Text('Skill hinzufügen'),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _nextStep,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Los geht's!"),
          ),
        ],
      ),
    );
  }
}

class _SelectedSkill {
  final Skill skill;
  final String description;

  const _SelectedSkill({required this.skill, required this.description});
}
