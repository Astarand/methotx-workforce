import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/app_drawer.dart';
import '../shared/widgets/app_bottom_nav.dart';
import '../features/authentication/presentation/controllers/auth_notifier.dart';
import '../features/notifications/presentation/controllers/notification_controller.dart';
import 'app_startup_notifier.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget child;

  const MainShellScreen({
    super.key,
    required this.child,
  });

  int? _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/dashboard' || location.startsWith('/dashboard/')) return 0;
    if (location == '/tasks' || location.startsWith('/tasks/')) return 1;
    if (location == '/leave' || location.startsWith('/leave/')) return 2;
    if (location == '/profile' || location.startsWith('/profile/')) return 3;
    return null;
  }

  void _onBottomNavTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/tasks');
        break;
      case 2:
        context.go('/leave');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final currentRoute = GoRouterState.of(context).uri.path;
    final notifState = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        currentRoute: currentRoute,
        onNavigate: (route) {
          context.go(route);
        },
        onLogout: () async {
          // Clear remote session via Clean Architecture provider
          await ref.read(authNotifierProvider.notifier).logout();
          // Clear local startup state & storage, which automatically triggers router redirect to /login
          await ref.read(appStartupProvider.notifier).logout();
        },
      ),
      appBar: AppHeader(
        unreadNotificationCount: notifState.unreadCount,
        onNotificationPressed: () {
          context.push('/notifications');
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AppBottomNavigation(
              currentIndex: selectedIndex,
              onTap: (index) => _onBottomNavTapped(index, context),
            ),
          ),
        ],
      ),
    );
  }
}
