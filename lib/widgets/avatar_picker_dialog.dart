import 'package:flutter/material.dart';

class AvatarPickerDialog extends StatefulWidget {
  const AvatarPickerDialog({super.key});

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedAvatar;

  // Generate avatar URLs from the API
  static const String _baseUrl = 'https://avatar.iran.liara.run/public';

  // Using numbered avatars - the API has about 100 public avatars
  // We'll show 20 from each category for simplicity
  final List<String> _maleAvatars = List.generate(
    20,
    (index) => '$_baseUrl/${index + 1}',
  );

  final List<String> _femaleAvatars = List.generate(
    20,
    (index) => '$_baseUrl/${index + 51}', // Offset to get different avatars
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.face_rounded, color: colorScheme.primary),
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
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Male', icon: Icon(Icons.man_rounded)),
                Tab(text: 'Female', icon: Icon(Icons.woman_rounded)),
              ],
            ),

            // Avatar Grid
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAvatarGrid(_maleAvatars),
                  _buildAvatarGrid(_femaleAvatars),
                ],
              ),
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
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : Colors.transparent,
                width: 3,
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
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.person_rounded,
                      color: colorScheme.onSurfaceVariant,
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
