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

/// Floating bottom bar: a rounded white pill with a soft shadow, a tinted
/// indicator behind the active tab, and a raised gradient "Start" button in
/// the middle.
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
            radius: 32,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 48,
                height: 32,
                decoration: BoxDecoration(color: on ? AppColors.brandTint : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.chip)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(on ? active : icon, key: ValueKey(on), color: color, size: 22),
                ),
              ),
              const SizedBox(height: 3),
              Text(label, style: AppText.tiny.copyWith(color: color, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
            ]),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.xs, AppSpace.md, AppSpace.sm),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.feature),
            border: Border.all(color: AppColors.line.withValues(alpha: 0.7)),
            boxShadow: AppShadows.floating,
          ),
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
                  radius: 32,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 48,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: AppGradients.button,
                        borderRadius: BorderRadius.circular(AppRadius.photo),
                        boxShadow: AppShadows.brand,
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(height: 3),
                    Text('Start', style: AppText.tiny.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w800)),
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
