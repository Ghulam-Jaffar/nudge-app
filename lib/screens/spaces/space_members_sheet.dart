import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/space_model.dart';
import '../../models/user_model.dart';
import '../../providers/providers.dart';

class SpaceMembersSheet extends ConsumerStatefulWidget {
  final Space space;

  const SpaceMembersSheet({
    super.key,
    required this.space,
  });

  static Future<void> show(BuildContext context, {required Space space}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SpaceMembersSheet(space: space),
    );
  }

  @override
  ConsumerState<SpaceMembersSheet> createState() => _SpaceMembersSheetState();
}

class _SpaceMembersSheetState extends ConsumerState<SpaceMembersSheet> {
  final Map<String, AppUser?> _memberUsers = {};
  bool _isLoading = true;
  String? _processingUid;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final userService = ref.read(userServiceProvider);

    for (final uid in widget.space.members.keys) {
      final user = await userService.getUser(uid);
      if (mounted) {
        setState(() {
          _memberUsers[uid] = user;
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String uid) async {
    final member = widget.space.members[uid];
    final user = _memberUsers[uid];

    if (member == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove ${user?.displayName ?? 'this member'} from the space?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingUid = uid);

    final spaceService = ref.read(spaceServiceProvider);
    final success = await spaceService.removeMember(
      spaceId: widget.space.spaceId,
      uid: uid,
    );

    if (!mounted) return;

    setState(() => _processingUid = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user?.displayName ?? 'Member'} removed'),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to remove member'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _updateRole(String uid, MemberRole newRole) async {
    setState(() => _processingUid = uid);

    final spaceService = ref.read(spaceServiceProvider);
    final success = await spaceService.updateMemberRole(
      spaceId: widget.space.spaceId,
      uid: uid,
      role: newRole,
    );

    if (!mounted) return;

    setState(() => _processingUid = null);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role updated to ${newRole.name}'),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update role'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showMemberOptions(String uid, SpaceMember member, AppUser? user) {
    final currentUser = ref.read(currentUserProvider);
    final isCurrentUser = uid == currentUser?.uid;
    final isOwner = widget.space.ownerUid == currentUser?.uid;
    final currentMember = currentUser != null
        ? widget.space.members[currentUser.uid]
        : null;
    final isAdmin = currentMember?.role == MemberRole.admin || isOwner;

    // Can't modify owner, or can't modify if not admin
    if (member.role == MemberRole.owner || !isAdmin || isCurrentUser) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(user?.displayName ?? 'Unknown'),
              subtitle: Text('@${user?.handle ?? uid}'),
            ),
            const Divider(),
            if (isOwner) ...[
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Make Admin'),
                enabled: member.role != MemberRole.admin,
                onTap: () {
                  Navigator.pop(context);
                  _updateRole(uid, MemberRole.admin);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Make Member'),
                enabled: member.role != MemberRole.member,
                onTap: () {
                  Navigator.pop(context);
                  _updateRole(uid, MemberRole.member);
                },
              ),
            ],
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Remove from Space',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeMember(uid);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = widget.space.ownerUid == currentUser?.uid;
    final currentMember = currentUser != null
        ? widget.space.members[currentUser.uid]
        : null;
    final isAdmin = currentMember?.role == MemberRole.admin || isOwner;

    // Sort members: owner first, then admins, then members
    final sortedMembers = widget.space.members.entries.toList()
      ..sort((a, b) {
        final roleOrder = {
          MemberRole.owner: 0,
          MemberRole.admin: 1,
          MemberRole.member: 2,
        };
        return roleOrder[a.value.role]!.compareTo(roleOrder[b.value.role]!);
      });

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 60),
                Text(
                  'Members (${widget.space.memberCount})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),

          const Divider(),

          // Members list
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedMembers.length,
                    itemBuilder: (context, index) {
                      final entry = sortedMembers[index];
                      final uid = entry.key;
                      final member = entry.value;
                      final user = _memberUsers[uid];
                      final isProcessing = _processingUid == uid;
                      final isCurrentUser = uid == currentUser?.uid;
                      final canModify = isAdmin &&
                          !isCurrentUser &&
                          member.role != MemberRole.owner;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!)
                              : null,
                          child: user?.photoUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  color: colorScheme.primary,
                                )
                              : null,
                        ),
                        title: Text(
                          user?.displayName ?? 'Loading...',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          user != null ? '@${user.handle}' : '',
                        ),
                        trailing: isProcessing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrentUser)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'You',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onTertiaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  _RoleBadge(role: member.role),
                                  if (canModify) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ],
                                ],
                              ),
                        onTap: canModify
                            ? () => _showMemberOptions(uid, member, user)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    String label;

    switch (role) {
      case MemberRole.owner:
        backgroundColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        label = 'Owner';
        break;
      case MemberRole.admin:
        backgroundColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
        label = 'Admin';
        break;
      case MemberRole.member:
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface.withValues(alpha: 0.7);
        label = 'Member';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
