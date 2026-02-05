import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_packs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final currentUser = ref.read(currentUserProvider);

      // Unregister FCM token before signing out
      if (currentUser != null) {
        final fcmService = ref.read(fcmServiceProvider);
        await fcmService.unregisterToken(currentUser.uid);
      }

      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (context.mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeState = ref.watch(themeProvider);
    final appUser = ref.watch(appUserProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('Profile'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Avatar and user info
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: appUser?.photoUrl != null
                        ? NetworkImage(appUser!.photoUrl!)
                        : null,
                    child: appUser?.photoUrl == null
                        ? Icon(
                            Icons.person_rounded,
                            size: 50,
                            color: colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    appUser?.displayName ?? 'Loading...',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appUser != null ? '@${appUser.handle}' : '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit profile coming soon!'),
                        ),
                      );
                    },
                    child: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Appearance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Theme mode selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Mode',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<AppThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: AppThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded),
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded),
                                label: Text('Dark'),
                              ),
                              ButtonSegment(
                                value: AppThemeMode.system,
                                icon: Icon(Icons.settings_brightness_rounded),
                                label: Text('System'),
                              ),
                            ],
                            selected: {themeState.mode},
                            onSelectionChanged: (selection) {
                              ref
                                  .read(themeProvider.notifier)
                                  .setMode(selection.first);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Theme pack selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theme Pack',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ThemePacks.all.map((pack) {
                              final isSelected =
                                  themeState.pack.id == pack.id;
                              return ChoiceChip(
                                label: Text(pack.name),
                                selected: isSelected,
                                onSelected: (_) {
                                  ref
                                      .read(themeProvider.notifier)
                                      .setPack(pack);
                                },
                                avatar: CircleAvatar(
                                  backgroundColor: pack.primaryColor,
                                  radius: 10,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notifications'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notification settings coming soon!'),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('Privacy Policy'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/privacy-policy'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.logout_rounded,
                            color: colorScheme.error,
                          ),
                          title: Text(
                            'Sign Out',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          onTap: () => _signOut(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // App info
                  Text(
                    'Nudge v1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
