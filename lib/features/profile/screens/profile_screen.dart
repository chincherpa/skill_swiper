import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/profile.dart';
import '../../../models/skill.dart';
import '../../../models/user_skill.dart';
import '../../../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = SupabaseService();
  Profile? _profile;
  List<UserSkill> _skills = [];
  bool _loading = true;
  bool _editing = false;

  // Edit controllers
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final userId = _service.currentUserId!;
      final profile = await _service.getProfile(userId);
      final skills = await _service.getUserSkills(userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _skills = skills;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startEditing() {
    _nameController.text = _profile?.name ?? '';
    _bioController.text = _profile?.bio ?? '';
    setState(() => _editing = true);
  }

  Future<void> _saveEdits() async {
    if (_profile == null) return;
    try {
      final updated = _profile!.copyWith(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
      );
      await _service.upsertProfile(updated);
      setState(() {
        _profile = updated;
        _editing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final url =
          await _service.uploadAvatar(_service.currentUserId!, bytes);
      final updated = _profile!.copyWith(avatarUrl: url);
      await _service.upsertProfile(updated);
      setState(() => _profile = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Hochladen: $e')),
        );
      }
    }
  }

  Future<void> _removeSkill(UserSkill skill) async {
    try {
      await _service.removeUserSkill(skill.id);
      setState(() => _skills.remove(skill));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _addSkill() async {
    List<Skill> catalog;
    try {
      catalog = await _service.getSkillCatalog();
    } catch (_) {
      return;
    }

    final existingIds = _skills.map((s) => s.skillId).toSet();
    final available =
        catalog.where((s) => !existingIds.contains(s.id)).toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle Skills bereits hinzugefügt')),
        );
      }
      return;
    }

    final descController = TextEditingController();
    Skill? chosen;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
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
                        children: sortedCategories.map((cat) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(cat,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: categories[cat]!.map((s) {
                                  return ActionChip(
                                    label: Text(s.name),
                                    onPressed: () =>
                                        setDialogState(() => chosen = s),
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
                        hintText: 'z.B. Zeige dir in 2h die Basics...',
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
                      ? () => Navigator.pop(ctx, {
                            'skillId': chosen!.id,
                            'description': descController.text.trim(),
                          })
                      : null,
                  child: const Text('Hinzufügen'),
                ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      try {
        await _service.addUserSkill(
          skillId: result['skillId']!,
          description: result['description']!,
        );
        await _loadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mein Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveEdits,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _startEditing,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: _changeAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.background,
                    backgroundImage: _profile?.avatarUrl != null
                        ? NetworkImage(_profile!.avatarUrl!)
                        : null,
                    child: _profile?.avatarUrl == null
                        ? const Icon(Icons.person,
                            size: 60, color: AppColors.textSecondary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary,
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name
            if (_editing)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                maxLength: 50,
                textAlign: TextAlign.center,
              )
            else
              Text(
                _profile?.name ?? 'Unbekannt',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 8),

            // Bio
            if (_editing)
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLength: 300,
                maxLines: 3,
              )
            else
              Text(
                _profile?.bio ?? 'Keine Bio',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),

            // Location info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _profile?.latitude != null
                      ? 'Standort gesetzt · ${_profile!.radiusKm} km Umkreis'
                      : 'Kein Standort',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Skills section
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Meine Skills',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addSkill,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _skills.isEmpty
                  ? Center(
                      child: Text(
                        'Noch keine Skills hinzugefügt',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _skills.length,
                      itemBuilder: (context, index) {
                        final skill = _skills[index];
                        return Card(
                          child: ListTile(
                            title: Text(skill.skillName ?? 'Skill'),
                            subtitle: Text(skill.description),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _removeSkill(skill),
                              color: AppColors.swipeLeft,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _service.signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Abmelden'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.swipeLeft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
