import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth.dart';

/// Chrome around the authenticated app: top nav + role-aware links + logout.
class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lead Platform'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge,
        actions: [
          _NavButton(
            label: 'Leads',
            selected: location.startsWith('/app/leads'),
            onTap: () => context.go('/app/leads'),
          ),
          // Admin-only navigation. The route itself is also guarded.
          if (auth.isAdmin)
            _NavButton(
              label: 'Team',
              selected: location.startsWith('/app/users'),
              onTap: () => context.go('/app/users'),
            ),
          const SizedBox(width: 12),
          if (user != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'logout') {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text('${user.name} · ${user.role.name}'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(
                        user.name.isNotEmpty
                            ? user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
