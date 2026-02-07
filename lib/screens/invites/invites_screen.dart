import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/invite_model.dart';
import '../../providers/providers.dart';
import '../../widgets/mascot_image.dart';
import '../../utils/error_messages.dart';

class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  final Set<String> _processingInvites = {};

  Future<void> _acceptInvite(SpaceInvite invite) async {
    setState(() => _processingInvites.add(invite.inviteId));

    final inviteService = ref.read(inviteServiceProvider);
    final success = await inviteService.acceptInvite(invite.inviteId);

    if (!mounted) return;

    setState(() => _processingInvites.remove(invite.inviteId));

    if (success) {
      // Invalidate providers to force refresh with new membership
      ref.invalidate(userSpacesProvider);
      ref.invalidate(spaceProvider(invite.spaceId));
      ref.invalidate(spaceItemsProvider(invite.spaceId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${invite.spaceNameSnapshot}!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to accept invitation'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _declineInvite(SpaceInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Invitation'),
        content: Text(
          'Are you sure you want to decline the invitation to "${invite.spaceNameSnapshot}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingInvites.add(invite.inviteId));

    final inviteService = ref.read(inviteServiceProvider);
    final success = await inviteService.declineInvite(invite.inviteId);

    if (!mounted) return;

    setState(() => _processingInvites.remove(invite.inviteId));

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to decline invitation'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final invites = ref.watch(pendingInvitesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitations'),
      ),
      body: invites.when(
        data: (inviteList) {
          if (inviteList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MascotImage(
                    variant: MascotVariant.happy,
                    size: 100,
                    fallbackIcon: Icons.mail_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending invitations',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When someone invites you to a space,\nit will appear here',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: inviteList.length,
            itemBuilder: (context, index) {
              final invite = inviteList[index];
              final isProcessing = _processingInvites.contains(invite.inviteId);

              return _InviteCard(
                invite: invite,
                isProcessing: isProcessing,
                onAccept: () => _acceptInvite(invite),
                onDecline: () => _declineInvite(invite),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MascotImage(
                variant: MascotVariant.sad,
                size: 100,
                fallbackIcon: Icons.cloud_off_rounded,
              ),
              const SizedBox(height: 24),
              Text(
                ErrorMessages.friendly(error),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final SpaceInvite invite;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({
    required this.invite,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.group_work_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.spaceNameSnapshot,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(invite.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isProcessing)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}
