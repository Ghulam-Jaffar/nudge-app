import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/providers.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/handle_setup_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/personal_items/personal_items_screen.dart';
import 'screens/spaces/spaces_list_screen.dart';
import 'screens/spaces/space_detail_screen.dart';
import 'screens/invites/invites_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/privacy_policy_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final hasProfile = ref.watch(hasCompletedProfileProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final isLoggedIn = authState.valueOrNull != null;
      final isLoggingIn = state.uri.path.startsWith('/auth');
      final isOnLoading = state.uri.path == '/loading';

      // Show loading screen while checking auth state
      if (isLoading && !isOnLoading) {
        return '/loading';
      }

      // Once loaded, redirect away from loading screen
      if (!isLoading && isOnLoading) {
        return isLoggedIn ? '/' : '/auth';
      }

      // If not logged in and not on auth screen, redirect to welcome
      if (!isLoading && !isLoggedIn && !isLoggingIn) {
        return '/auth';
      }

      // If logged in but no handle set, redirect to handle setup
      if (!isLoading && isLoggedIn && !hasProfile && state.uri.path != '/auth/setup-handle') {
        return '/auth/setup-handle';
      }

      // If logged in with profile and on auth screen, redirect to home
      if (!isLoading && isLoggedIn && hasProfile && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      // Loading screen
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),

      // Auth routes (no shell)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'signin',
            pageBuilder: (context, state) => _buildPageTransition(
              state, const SignInScreen(),
            ),
          ),
          GoRoute(
            path: 'signup',
            pageBuilder: (context, state) => _buildPageTransition(
              state, const SignUpScreen(),
            ),
          ),
          GoRoute(
            path: 'setup-handle',
            pageBuilder: (context, state) => _buildPageTransition(
              state, const HandleSetupScreen(),
            ),
          ),
        ],
      ),

      // Main app routes (with bottom nav shell)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PersonalItemsScreen(),
            ),
          ),
          GoRoute(
            path: '/spaces',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SpacesListScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Routes outside shell (with back navigation)
      GoRoute(
        path: '/spaces/:spaceId',
        pageBuilder: (context, state) => _buildPageTransition(
          state,
          SpaceDetailScreen(spaceId: state.pathParameters['spaceId']!),
        ),
      ),
      GoRoute(
        path: '/invites',
        pageBuilder: (context, state) => _buildPageTransition(
          state, const InvitesScreen(),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        pageBuilder: (context, state) => _buildPageTransition(
          state, const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (context, state) => _buildPageTransition(
          state, const PrivacyPolicyScreen(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<void> _buildPageTransition(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.25, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      );
    },
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
