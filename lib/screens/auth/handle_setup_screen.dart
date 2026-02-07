import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/avatar_picker_dialog.dart';

class HandleSetupScreen extends ConsumerStatefulWidget {
  const HandleSetupScreen({super.key});

  @override
  ConsumerState<HandleSetupScreen> createState() => _HandleSetupScreenState();
}

class _HandleSetupScreenState extends ConsumerState<HandleSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _selectedPhotoUrl;
  bool _isLoading = false;
  bool _isCheckingHandle = false;
  String? _handleError;
  bool _handleAvailable = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Pre-fill display name from Firebase user if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      _displayNameController.text = user.displayName!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _handleController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _checkHandleAvailability(String handle) async {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (handle.isEmpty || handle.length < 3) {
      setState(() {
        _handleError = null;
        _handleAvailable = false;
        _isCheckingHandle = false;
      });
      return;
    }

    // Validate format first
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(handle)) {
      setState(() {
        _handleError = 'Only letters, numbers, and underscores';
        _handleAvailable = false;
        _isCheckingHandle = false;
      });
      return;
    }

    setState(() {
      _isCheckingHandle = true;
      _handleError = null;
      _handleAvailable = false;
    });

    // Debounce the check
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final userService = ref.read(userServiceProvider);
      final isAvailable = await userService.isHandleAvailable(handle);

      if (mounted && _handleController.text == handle) {
        setState(() {
          _isCheckingHandle = false;
          if (isAvailable == null) {
            // Error occurred - allow user to try saving anyway
            _handleAvailable = true;
            _handleError = null;
            debugPrint('Handle check failed, allowing user to proceed');
          } else if (isAvailable) {
            _handleAvailable = true;
            _handleError = null;
          } else {
            _handleAvailable = false;
            _handleError = 'This handle is already taken';
          }
        });
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_handleError != null || !_handleAvailable) {
      _showError('Please choose an available handle');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Not authenticated. Please sign in again.');
      context.go('/auth');
      return;
    }

    setState(() => _isLoading = true);

    final userService = ref.read(userServiceProvider);
    final success = await userService.reserveHandle(
      uid: user.uid,
      handle: _handleController.text.trim(),
      displayName: _displayNameController.text.trim(),
      photoUrl: _selectedPhotoUrl ?? user.photoURL,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      // Register FCM token for push notifications
      final fcmService = ref.read(fcmServiceProvider);
      await fcmService.registerToken(user.uid);
      if (!mounted) return;
      context.go('/');
    } else {
      _showError('Failed to save profile. Handle may have been taken.');
      // Re-check availability
      _checkHandleAvailability(_handleController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your profile'),
        automaticallyImplyLeading: false,
        actions: [
          // Allow sign out if user wants to use a different account
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final authService = ref.read(authServiceProvider);
                    final navigator = GoRouter.of(context);
                    await authService.signOut();
                    if (mounted) {
                      navigator.go('/auth');
                    }
                  },
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.1),
                            backgroundImage: _selectedPhotoUrl != null
                                ? NetworkImage(_selectedPhotoUrl!)
                                : (user?.photoURL != null
                                    ? NetworkImage(user!.photoURL!)
                                    : null),
                            child: _selectedPhotoUrl == null && user?.photoURL == null
                                ? Text(
                                    _displayNameController.text.isNotEmpty
                                        ? _displayNameController.text[0].toUpperCase()
                                        : (user?.displayName?.isNotEmpty == true
                                            ? user!.displayName![0].toUpperCase()
                                            : '?'),
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.face_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        final selectedUrl =
                                            await showAvatarPicker(context);
                                        if (selectedUrl != null) {
                                          setState(() {
                                            _selectedPhotoUrl = selectedUrl.isEmpty ? null : selectedUrl;
                                          });
                                        }
                                      },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final selectedUrl =
                                    await showAvatarPicker(context);
                                if (selectedUrl != null) {
                                  setState(() {
                                    _selectedPhotoUrl = selectedUrl.isEmpty ? null : selectedUrl;
                                  });
                                }
                              },
                        icon: const Icon(Icons.face_rounded, size: 18),
                        label: const Text('Choose Avatar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _displayNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                    hintText: 'How should we call you?',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a display name';
                    }
                    if (value.trim().length < 2) {
                      return 'Display name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _handleController,
                  textInputAction: TextInputAction.done,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Handle',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    prefixText: '@',
                    hintText: 'your_unique_handle',
                    errorText: _handleError,
                    suffixIcon: _isCheckingHandle
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _handleAvailable
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: colorScheme.primary,
                              )
                            : null,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a handle';
                    }
                    if (value.length < 3) {
                      return 'Handle must be at least 3 characters';
                    }
                    if (value.length > 20) {
                      return 'Handle must be 20 characters or less';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                      return 'Only letters, numbers, and underscores';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    _checkHandleAvailability(value);
                  },
                  onFieldSubmitted: (_) => _saveProfile(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Friends can find you using your handle',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading || _isCheckingHandle || !_handleAvailable
                      ? null
                      : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
