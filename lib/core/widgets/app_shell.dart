import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/widgets/floating_cart_bar.dart';

/// Bottom-nav shell: الرئيسية, الأقسام, العروض, طلباتي, حسابي — plus the
/// floating cart bar, which overlays every tab once the cart has items.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية'),
    (icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'الأقسام'),
    (icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer, label: 'العروض'),
    (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'طلباتي'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'حسابي'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          if (navigationShell.currentIndex == 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FloatingCartBar(onViewCart: () => context.push('/cart')),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
