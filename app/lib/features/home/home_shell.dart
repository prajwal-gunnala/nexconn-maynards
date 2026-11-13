import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Bottom-nav shell: Street, Buckets, [Start], Chats, Wallet. Each tab keeps its
/// own navigation stack (go_router StatefulShellRoute.indexedStack). The middle
/// slot is a hero action that opens "Start a bucket".
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _goTab(int i) {
    // Drop any text focus (e.g. Buckets search) so the keyboard can't reopen
    // over the bottom nav on the new tab.
    FocusManager.instance.primaryFocus?.unfocus();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Android back on any other tab returns to Street first; back on Street exits.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && shell.currentIndex != 0) _goTab(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: StreetNavBar(
          currentIndex: shell.currentIndex,
          onTab: _goTab,
          onStart: () {
            FocusManager.instance.primaryFocus?.unfocus();
            context.push('/create');
          },
        ),
      ),
    );
  }
}

/// Licious-style bottom bar: outline icons + 11 sp labels, brand when active,
/// hairline top border, and an emphasised "Start" tile in the middle.
class StreetNavBar extends StatelessWidget {
  const StreetNavBar({super.key, required this.currentIndex, required this.onTab, required this.onStart});

  final int currentIndex;
  final ValueChanged<int> onTab;
  final VoidCallback onStart;

  static const _tabs = [
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Street'),
    (Icons.shopping_basket_outlined, Icons.shopping_basket_rounded, 'Buckets'),
    (Icons.forum_outlined, Icons.forum_rounded, 'Chats'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Wallet'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) {
      final (icon, active, label) = _tabs[i];
      final on = i == currentIndex;
      final color = on ? AppColors.brand : AppColors.inkMuted;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 36,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(
                height: 32,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(on ? active : icon, key: ValueKey(on), color: color, size: 24),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppText.tiny.copyWith(color: color, fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: [
            tab(0),
            tab(1),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Start a bucket',
                excludeSemantics: true,
                child: InkResponse(
                  onTap: onStart,
                  radius: 36,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 44,
                      height: 32,
                      decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(AppRadius.photo)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text('Start', style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
            tab(2),
            tab(3),
          ]),
        ),
      ),
    );
  }
}
