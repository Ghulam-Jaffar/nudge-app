import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../models/space_model.dart';
import '../../providers/providers.dart';

class InviteUserSheet extends ConsumerStatefulWidget {
  final Space space;

  const InviteUserSheet({
    super.key,
    required this.space,
  });

  static Future<bool?> show(BuildContext context, {required Space space}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => InviteUserSheet(space: space),
    );
  }

  @override
  ConsumerState<InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends ConsumerState<InviteUserSheet> {
  final _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isSearching = false;
  bool _isInviting = false;
  String? _invitingUid;
  Timer? _debounceTimer;
  final Set<String> _invitedUids = {}; // Track already invited users

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final userService = ref.read(userServiceProvider);
      final results = await userService.searchUsersByHandle(query.trim());

      if (mounted && _searchController.text == query) {
        setState(() {
          // Filter out current user and existing members
          final currentUid = ref.read(currentUserProvider)?.uid;
          _searchResults = results.where((user) {
            if (user.uid == currentUid) return false;
            if (widget.space.members.containsKey(user.uid)) return false;
            return true;
          }).toList();
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _inviteUser(AppUser user) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _isInviting = true;
      _invitingUid = user.uid;
    });

    final inviteService = ref.read(inviteServiceProvider);
    final invite = await inviteService.createInvite(
      spaceId: widget.space.spaceId,
      spaceName: widget.space.name,
      fromUid: currentUser.uid,
      toUid: user.uid,
    );

    if (!mounted) return;

    setState(() {
      _isInviting = false;
      _invitingUid = null;
    });

    if (invite != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to @${user.handle}'),
        ),
      );
      // Mark user as invited so button changes to "Invited"
      setState(() {
        _invitedUids.add(user.uid);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not invite @${user.handle}. They may already have a pending invite.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                    'Invite to ${widget.space.name}',
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

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by @handle',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            _search('');
                          },
                        )
                      : null,
                ),
                onChanged: _search,
              ),
            ),

            // Results
            Expanded(
              child: _buildContent(theme, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for users',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a handle to find people to invite',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final isInvitingThis = _isInviting && _invitingUid == user.uid;
        final isAlreadyInvited = _invitedUids.contains(user.uid);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Icon(
                      Icons.person_rounded,
                      color: colorScheme.primary,
                    )
                  : null,
            ),
            title: Text(user.displayName),
            subtitle: Text('@${user.handle}'),
            trailing: isInvitingThis
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : isAlreadyInvited
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Invited',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : TextButton(
                        onPressed: _isInviting ? null : () => _inviteUser(user),
                        child: const Text('Invite'),
                      ),
          ),
        );
      },
    );
  }
}
