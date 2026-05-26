import 'package:chat_app/core/router/app_paths.dart';
import 'package:chat_app/core/router/app_route_args.dart';
import 'package:chat_app/core/router/app_routes.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/presentation/screens/auth/login_screen.dart';
import 'package:chat_app/presentation/screens/chat/chat_screen.dart';
import 'package:chat_app/presentation/screens/home/home_screen.dart';
import 'package:chat_app/presentation/screens/profile/profile_screen.dart';
import 'package:chat_app/presentation/screens/chat/widgets/image_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter createAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppPaths.login,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final authStatus = authProvider.status;
      final isLoggedIn = authStatus == AuthStatus.authenticated;
      final isOnLogin = state.matchedLocation == AppPaths.login;

      if (isLoggedIn && isOnLogin) {
        return AppPaths.home;
      }

      if (!isLoggedIn && !isOnLogin) {
        return AppPaths.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.login,
        name: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppPaths.home,
        name: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppPaths.profile,
        name: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppPaths.chat,
        name: AppRoutes.chat,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ChatRouteArgs) {
            return const Scaffold(
              body: Center(child: Text('Missing chat route data')),
            );
          }
          return ChatScreen(otherUser: args.otherUser);
        },
      ),
      GoRoute(
        path: AppPaths.imagePreview,
        name: AppRoutes.imagePreview,
        builder: (context, state) {
          final args = state.extra;
          if (args is! ImagePreviewRouteArgs) {
            return const Scaffold(
              body: Center(child: Text('Missing image preview data')),
            );
          }
          return ImagePreviewScreen(
            file: args.file,
            initialCaption: args.initialCaption,
          );
        },
      ),
    ],
  );
}
