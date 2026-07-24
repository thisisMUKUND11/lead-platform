import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pages/app_shell.dart';
import 'pages/capture_page.dart';
import 'pages/lead_detail_page.dart';
import 'pages/leads_page.dart';
import 'pages/login_page.dart';
import 'pages/users_page.dart';
import 'state/auth.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Wait until we've checked for a persisted session.
      if (auth.initializing) return null;

      final location = state.matchedLocation;
      final inApp = location.startsWith('/app');

      // Unauthenticated users may only see the public form and login.
      if (!auth.isAuthenticated) {
        return inApp ? '/login' : null;
      }

      // Authenticated: bounce away from the login page.
      if (location == '/login') return '/app/leads';

      // Client-side role guard: members cannot open the admin area.
      // (The server enforces this too — this only hides the UI.)
      if (location.startsWith('/app/users') && !auth.isAdmin) {
        return '/app/leads';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const CapturePage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/leads',
            builder: (_, _) => const LeadsPage(),
          ),
          GoRoute(
            path: '/app/leads/:id',
            builder: (_, state) =>
                LeadDetailPage(leadId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/app/users',
            builder: (_, _) => const UsersPage(),
          ),
        ],
      ),
    ],
  );
});

class LeadPlatformApp extends ConsumerWidget {
  const LeadPlatformApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Lead Platform',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
