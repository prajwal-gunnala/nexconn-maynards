import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/images.dart';
import '../../core/session/session_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/widgets.dart';
import 'onboarding_art.dart';

/// Welcome: a three-slide pager (what it is, how money is held, how it arrives),
/// then phone login. Vendors take the secondary path to the same login.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.initialPage = 0});

  /// For screenshots and deep links.
  final int initialPage;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Slide {
  const _Slide(this.title, this.body);
  final String title;
  final String body;
}

const _slides = [
  _Slide('Wholesale prices for your whole street',
      'Start a bucket for a whole fish, a sack of rice or a pest-control visit. Neighbours claim their share in your society chat.'),
  _Slide('Your money is only held, not paid, until the bucket fills',
      'Your money is only held until the bucket fills. Everyone pays the final group price, and anything extra goes straight back.'),
  _Slide('One order, one delivery to your gate',
      'The vendor gets one order with every flat on it, packs it, and drops it at your gate. You collect with a code.'),
];

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final _page = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  bool get _last => _index == _slides.length - 1;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final s = context.read<SessionStore>();
    if (!s.onboarded) await s.markOnboarded();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(width: AppSpace.gutter),
              const BrandWordmark(size: 32),
              const Spacer(),
              AnimatedOpacity(
                opacity: _last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _last ? null : _finish,
                  style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted, minimumSize: const Size(64, 48)),
                  child: Text('Skip', style: AppText.label.copyWith(color: AppColors.inkMuted, fontSize: 14)),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _SlideView(index: i, slide: _slides[i]),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _index ? AppColors.brand : const Color(0xFFE6DDD7),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.sm),
            child: AppButton(
              label: _last ? 'Get started' : 'Next',
              icon: null,
              onPressed: _next,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.md),
            child: TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 48), foregroundColor: AppColors.brandDeep),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.storefront_outlined, size: 18),
                const SizedBox(width: AppSpace.sm),
                Text('I sell to communities', style: AppText.label.copyWith(color: AppColors.brandDeep, fontSize: 14)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.index, required this.slide});

  final int index;
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final art = switch (index) {
      0 => const StreetArt(),
      1 => const HeldArt(),
      _ => const GateArt(),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sheet),
            child: Image.asset(
              AppImages.onboarding(index + 1),
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => art,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        Semantics(header: true, child: Text(slide.title, style: AppText.display.copyWith(fontSize: 27))),
        const SizedBox(height: AppSpace.md),
        Text(slide.body, style: AppText.bodyMuted.copyWith(fontSize: 15, height: 1.45)),
        const SizedBox(height: AppSpace.xl),
      ]),
    );
  }
}
