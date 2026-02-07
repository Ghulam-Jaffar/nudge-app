import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/avatar_picker_dialog.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _photoUrlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider);
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
    _photoUrlController = TextEditingController(text: user?.photoUrl ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = ref.read(appUserProvider);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not found')),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    final userService = ref.read(userServiceProvider);
    final updates = <String, dynamic>{
      'displayName': _displayNameController.text.trim(),
    };

    // Only update photoUrl if it's not empty
    final photoUrl = _photoUrlController.text.trim();
    if (photoUrl.isNotEmpty) {
      updates['photoUrl'] = photoUrl;
    } else {
      updates['photoUrl'] = null;
    }

    final success = await userService.updateUser(user.uid, updates);

    if (mounted) {
      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile photo preview with change button
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: _photoUrlController.text.isNotEmpty
                        ? NetworkImage(_photoUrlController.text)
                        : (user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null),
                    child: (_photoUrlController.text.isEmpty && user?.photoUrl == null)
                        ? Text(
                            _displayNameController.text.isNotEmpty
                                ? _displayNameController.text[0].toUpperCase()
                                : (user?.displayName.isNotEmpty == true
                                    ? user!.displayName[0].toUpperCase()
                                    : '?'),
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  FloatingActionButton.small(
                    onPressed: () async {
                      final selectedUrl = await showAvatarPicker(context);
                      if (selectedUrl != null) {
                        setState(() {
                          _photoUrlController.text = selectedUrl; // Empty string clears it
                        });
                      }
                    },
                    tooltip: 'Choose Avatar',
                    child: const Icon(Icons.edit_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  final selectedUrl = await showAvatarPicker(context);
                  if (selectedUrl != null) {
                    setState(() {
                      _photoUrlController.text = selectedUrl; // Empty string clears it
                    });
                  }
                },
                icon: const Icon(Icons.face_rounded),
                label: const Text('Choose Avatar'),
              ),
              const SizedBox(height: 24),

              // Display Name field
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your display name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name cannot be empty';
                  }
                  if (value.trim().length < 2) {
                    return 'Display name must be at least 2 characters';
                  }
                  if (value.trim().length > 50) {
                    return 'Display name must be less than 50 characters';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // Rebuild to update avatar preview
              ),
              const SizedBox(height: 16),

              // Photo URL field
              TextFormField(
                controller: _photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL',
                  hintText: 'Enter image URL (optional)',
                  prefixIcon: Icon(Icons.image_outlined),
                  border: OutlineInputBorder(),
                  helperText: 'Paste a link to your profile photo',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final uri = Uri.tryParse(value.trim());
                    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}), // Rebuild to update avatar preview
              ),
              const SizedBox(height: 24),

              // Handle info (read-only)
              Card(
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Handle',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user?.handle ?? ''}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Handle cannot be changed',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
