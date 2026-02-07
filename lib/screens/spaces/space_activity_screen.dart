import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/activity_model.dart';
import '../../models/invite_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../widgets/mascot_image.dart';

class SpaceActivityScreen extends ConsumerStatefulWidget {
  final String spaceId;

  const SpaceActivityScreen({
    super.key,
    required this.spaceId,
  });

  @override
  ConsumerState<SpaceActivityScreen> createState() => _SpaceActivityScreenState();
}

class _SpaceActivityScreenState extends ConsumerState<SpaceActivityScreen> {
  final Map<String, AppUser?> _userCache = {};

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(spaceActivitiesProvider(widget.spaceId));
    ref.invalidate(spaceInvitesProvider(widget.spaceId));
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<AppUser?> _getUser(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid];
    }
    final userService = ref.read(userServiceProvider);
    final user = await userService.getUser(uid);
    _userCache[uid] = user;
    return user;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activitiesAsync = ref.watch(spaceActivitiesProvider(widget.spaceId));
    final invitesAsync = ref.watch(spaceInvitesProvider(widget.spaceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: activitiesAsync.when(
          data: (activities) => invitesAsync.when(
            data: (invites) {

              final currentUser = ref.watch(currentUserProvider);
              // Combine and sort by date
              final allItems = <_TimelineItem>[];

              for (final activity in activities) {
                // Filter by visibleTo: show if null (public) or current user is in list
                if (activity.visibleTo != null &&
                    currentUser != null &&
                    !activity.visibleTo!.contains(currentUser.uid)) {
                  continue;
                }
                allItems.add(_TimelineItem(
                  dateTime: activity.createdAt,
                  isActivity: true,
                  activity: activity,
                ));
              }

              for (final invite in invites) {
                allItems.add(_TimelineItem(
                  dateTime: invite.createdAt,
                  isActivity: false,
                  invite: invite,
                ));
              }

              allItems.sort((a, b) => b.dateTime.compareTo(a.dateTime));

              if (allItems.isEmpty) {
                return _buildEmptyState(theme, colorScheme);
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: allItems.length,
                itemBuilder: (context, index) {
                  final item = allItems[index];
                  if (item.isActivity) {
                    return _ActivityTile(
                      activity: item.activity!,
                      getUser: _getUser,
                      formatTimeAgo: _formatTimeAgo,
                    );
                  } else {
                    return _InviteTile(
                      invite: item.invite!,
                      getUser: _getUser,
                      formatTimeAgo: _formatTimeAgo,
                    );
                  }
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint('Invites error: $error');
              return _buildScrollableError(context, theme, colorScheme);
            },
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('Activities error: $error');
            return _buildScrollableError(context, theme, colorScheme);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotImage(
            variant: MascotVariant.thinking,
            size: 80,
            fallbackIcon: Icons.history_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            'No activity yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity will appear here when\nmembers interact with this space',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableError(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        _buildErrorState(theme, colorScheme),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MascotImage(
            variant: MascotVariant.sad,
            size: 80,
            fallbackIcon: Icons.error_outline_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong. Please try again.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _onRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final DateTime dateTime;
  final bool isActivity;
  final SpaceActivity? activity;
  final SpaceInvite? invite;

  _TimelineItem({
    required this.dateTime,
    required this.isActivity,
    this.activity,
    this.invite,
  });
}

class _ActivityTile extends StatefulWidget {
  final SpaceActivity activity;
  final Future<AppUser?> Function(String) getUser;
  final String Function(DateTime) formatTimeAgo;

  const _ActivityTile({
    required this.activity,
    required this.getUser,
    required this.formatTimeAgo,
  });

  @override
  State<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<_ActivityTile> {
  AppUser? _actor;
  AppUser? _target;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final actor = await widget.getUser(widget.activity.actorUid);
    if (mounted) setState(() => _actor = actor);

    if (widget.activity.targetUid != null) {
      final target = await widget.getUser(widget.activity.targetUid!);
      if (mounted) setState(() => _target = target);
    }
  }

  IconData _getActivityIcon() {
    switch (widget.activity.type) {
      case ActivityType.inviteSent:
        return Icons.mail_outline_rounded;
      case ActivityType.inviteAccepted:
        return Icons.check_circle_outline_rounded;
      case ActivityType.inviteDeclined:
        return Icons.cancel_outlined;
      case ActivityType.memberJoined:
        return Icons.person_add_outlined;
      case ActivityType.memberLeft:
        return Icons.person_remove_outlined;
      case ActivityType.itemCreated:
        return Icons.add_circle_outline_rounded;
      case ActivityType.itemCompleted:
        return Icons.task_alt_rounded;
      case ActivityType.itemAssigned:
        return Icons.assignment_ind_outlined;
      case ActivityType.itemDeleted:
        return Icons.delete_outline_rounded;
      case ActivityType.itemUncompleted:
        return Icons.undo_rounded;
      case ActivityType.itemUpdated:
        return Icons.edit_outlined;
      case ActivityType.itemRestored:
        return Icons.restore_rounded;
      case ActivityType.memberRoleChanged:
        return Icons.admin_panel_settings_outlined;
      case ActivityType.ping:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = widget.activity.getDescription(
      actorName: _actor?.displayName,
      targetName: _target?.displayName,
    );

    // Build subtitle with optional metadata details
    String subtitleText = widget.formatTimeAgo(widget.activity.createdAt);
    if (widget.activity.type == ActivityType.itemUpdated &&
        widget.activity.metadata != null) {
      final changedFields =
          (widget.activity.metadata!['changedFields'] as List<dynamic>?)
              ?.cast<String>() ?? [];
      final details = <String>[];
      for (final field in changedFields) {
        switch (field) {
          case 'priority':
            final from = widget.activity.metadata!['priorityFrom'] as String?;
            final to = widget.activity.metadata!['priorityTo'] as String?;
            if (from != null && to != null) {
              details.add('Priority: ${from[0].toUpperCase()}${from.substring(1)} \u2192 ${to[0].toUpperCase()}${to.substring(1)}');
            }
          case 'assigned':
            details.add('Assignment changed');
          case 'remindAt':
            details.add('Reminder time changed');
        }
      }
      if (details.isNotEmpty) {
        subtitleText = '${details.join(', ')}\n$subtitleText';
      }
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: widget.activity.type == ActivityType.ping
            ? Colors.orange.withValues(alpha: 0.2)
            : colorScheme.primaryContainer,
        backgroundImage: _actor?.photoUrl != null
            ? NetworkImage(_actor!.photoUrl!)
            : null,
        child: _actor?.photoUrl == null
            ? Icon(
                _getActivityIcon(),
                color: widget.activity.type == ActivityType.ping
                    ? Colors.orange
                    : colorScheme.primary,
                size: 20,
              )
            : null,
      ),
      title: Text(description),
      subtitle: Text(subtitleText),
      isThreeLine: subtitleText.contains('\n'),
    );
  }
}

class _InviteTile extends StatefulWidget {
  final SpaceInvite invite;
  final Future<AppUser?> Function(String) getUser;
  final String Function(DateTime) formatTimeAgo;

  const _InviteTile({
    required this.invite,
    required this.getUser,
    required this.formatTimeAgo,
  });

  @override
  State<_InviteTile> createState() => _InviteTileState();
}

class _InviteTileState extends State<_InviteTile> {
  AppUser? _from;
  AppUser? _to;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final from = await widget.getUser(widget.invite.fromUid);
    if (mounted) setState(() => _from = from);

    final to = await widget.getUser(widget.invite.toUid);
    if (mounted) setState(() => _to = to);
  }

  String _getStatusText() {
    switch (widget.invite.status) {
      case InviteStatus.pending:
        return 'Pending';
      case InviteStatus.accepted:
        return 'Accepted';
      case InviteStatus.declined:
        return 'Declined';
      case InviteStatus.revoked:
        return 'Revoked';
    }
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (widget.invite.status) {
      case InviteStatus.pending:
        return colorScheme.tertiary;
      case InviteStatus.accepted:
        return Colors.green;
      case InviteStatus.declined:
        return colorScheme.error;
      case InviteStatus.revoked:
        return colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fromName = _from?.displayName ?? 'Someone';
    final toName = _to?.displayName ?? 'someone';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        child: Icon(Icons.mail_outline_rounded, color: colorScheme.secondary, size: 20),
      ),
      title: Text('$fromName invited $toName'),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(colorScheme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getStatusText(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _getStatusColor(colorScheme),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.formatTimeAgo(widget.invite.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
