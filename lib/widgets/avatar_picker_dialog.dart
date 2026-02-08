import 'package:flutter/material.dart';

enum AvatarGender { male, female }

class AvatarPickerDialog extends StatefulWidget {
  const AvatarPickerDialog({super.key});

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  AvatarGender _selectedGender = AvatarGender.male;
  String? _selectedAvatar;

  // iran.liara.run API - Beautiful, consistent avatars with proper gender separation
  static const String _baseUrl = 'https://avatar.iran.liara.run/public';

  // Use the username-based endpoints for proper gender separation
  final List<String> _maleUsernames = [
    'john', 'alex', 'mike', 'chris', 'david', 'james', 'robert', 'michael',
    'william', 'richard', 'thomas', 'charles', 'daniel', 'matthew', 'mark',
  ];

  final List<String> _femaleUsernames = [
    'sarah', 'jessica', 'emma', 'olivia', 'sophia', 'isabella', 'mia', 'charlotte',
    'amelia', 'harper', 'evelyn', 'abigail', 'emily', 'ella', 'madison',
  ];

  List<String> get _currentAvatars {
    if (_selectedGender == AvatarGender.male) {
      return _maleUsernames.map((name) => '$_baseUrl/boy?username=$name').toList();
    } else {
      return _femaleUsernames.map((name) => '$_baseUrl/girl?username=$name').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.face_rounded, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Choose Avatar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Gender selector (SegmentedButton like Today/Later/Done)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<AvatarGender>(
                segments: const [
                  ButtonSegment(
                    value: AvatarGender.male,
                    label: Text('Male'),
                    icon: Icon(Icons.man_rounded),
                  ),
                  ButtonSegment(
                    value: AvatarGender.female,
                    label: Text('Female'),
                    icon: Icon(Icons.woman_rounded),
                  ),
                ],
                selected: {_selectedGender},
                onSelectionChanged: (Set<AvatarGender> selection) {
                  setState(() {
                    _selectedGender = selection.first;
                    _selectedAvatar = null; // Clear selection when switching
                  });
                },
              ),
            ),

            const Divider(height: 1),

            // Avatar Grid
            Expanded(
              child: _buildAvatarGrid(_currentAvatars),
            ),

            // Footer buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''), // Empty string = clear avatar
                    child: const Text('Use Initials'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedAvatar != null
                        ? () => Navigator.pop(context, _selectedAvatar)
                        : null,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarGrid(List<String> avatars) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatarUrl = avatars[index];
        final isSelected = _selectedAvatar == avatarUrl;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAvatar = avatarUrl;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  // Show shimmer effect while loading
                  return Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        size: 28,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Show the avatar picker dialog and return the selected URL or null
Future<String?> showAvatarPicker(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const AvatarPickerDialog(),
  );
}
