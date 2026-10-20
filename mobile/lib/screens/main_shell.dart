import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'shop_menu_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [
    (Icons.home_outlined, 'Home'),
    (Icons.restaurant_menu, 'Menu'),
    (Icons.receipt_long_outlined, 'Orders'),
    (Icons.person_outline, 'User'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final body = switch (state.tab) {
      0 => const HomeScreen(),
      1 => ShopMenuScreen(key: ValueKey(state.selectedShopId), shopId: state.selectedShopId),
      2 => const OrdersScreen(),
      _ => const ProfileScreen(),
    };
    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border(bottom: BorderSide(color: AppColors.pink.withValues(alpha: 0.6), width: 3)),
            boxShadow: cardShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => state.goTab(i),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.tab == i ? AppColors.pink : Colors.transparent,
                        ),
                        child: Badge(
                          isLabelVisible: i == 1 && state.cartCount > 0,
                          label: Text('${state.cartCount}'),
                          backgroundColor: AppColors.accent,
                          child: Icon(_tabs[i].$1, size: 22, color: state.tab == i ? Colors.white : AppColors.ink2),
                        ),
                      ),
                      Text(_tabs[i].$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: state.tab == i ? FontWeight.w600 : FontWeight.w400,
                            color: state.tab == i ? AppColors.accent : AppColors.ink2,
                          )),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
