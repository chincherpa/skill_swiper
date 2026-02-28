import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
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
  final _cityController = TextEditingController();
  bool _geocoding = false;

  // Step 3: Skill
  final _skillDescriptionController = TextEditingController();
  bool _isRemote = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _skillDescriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _skillDescriptionController.dispose();
    super.dispose();
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

  Future<void> _geocodeCity() async {
    final query = _cityController.text.trim();
    if (query.isEmpty) return;

    setState(() => _geocoding = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        // Reverse geocode to get a readable name
        final placemarks =
            await placemarkFromCoordinates(loc.latitude, loc.longitude);
        final label = placemarks.isNotEmpty
            ? [placemarks.first.locality, placemarks.first.country]
                .where((s) => s != null && s.isNotEmpty)
                .join(', ')
            : '${loc.latitude.toStringAsFixed(2)}°, ${loc.longitude.toStringAsFixed(2)}°';

        setState(() {
          _latitude = loc.latitude;
          _longitude = loc.longitude;
          _locationLabel = label;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ort konnte nicht gefunden werden')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler bei der Suche: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
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
    final skillDesc = _skillDescriptionController.text.trim();
    if (skillDesc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Beschreibe, was du beibringen kannst')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = _service.currentUserId;
      if (userId == null) {
        throw Exception('Nicht angemeldet. Bitte erneut einloggen.');
      }

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

      // Save skill
      await _service.addUserSkill(
        description: skillDesc,
        isRemote: _isRemote,
      );

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
            label: const Text('Automatisch ermitteln'),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('oder',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Stadt / Ort eingeben',
                    hintText: 'z.B. Berlin, München...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _geocodeCity(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _geocoding ? null : _geocodeCity,
                icon: _geocoding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ],
          ),
          if (_locationLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.swipeRight, size: 18),
                const SizedBox(width: 4),
                Text(
                  _locationLabel!,
                  style: const TextStyle(
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
            'Dein Skill',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Was kannst du anderen beibringen?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _skillDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Beschreibe deinen Skill',
              hintText: 'z.B. Ich bringe dir Gitarre spielen bei',
            ),
            maxLength: 200,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _isRemote,
            onChanged: (value) {
              setState(() => _isRemote = value ?? false);
            },
            title: const Text('Kann remote beigebracht werden'),
            subtitle: const Text(
              'z.B. per Videocall',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _saving
                ? null
                : (_skillDescriptionController.text.trim().isNotEmpty
                    ? _nextStep
                    : null),
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
