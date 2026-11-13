import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/tokens.dart';

/// Size (dp) of the mark's 512-unit art box on the splash. Must match the native launch screens:
/// `res/drawable/splash_icon.xml` (Android 12+, scale 230/512) and `res/drawable-*/splash_logo.png` (older).
const double kSplashArtExtent = 230;

/// The glyph's visual centre in mark.svg units (centre of its enclosing circle). Native splashes put this
/// point at the centre of the screen, so we do too.
const Offset _kVisualCentre = Offset(256, 250);

// Timeline (ms) of the intro, then a short fade into the app.
const _kIntroMs = 1450;
const _kFadeMs = 260;
const _kBounce = (start: 80, end: 470);
const _kGoodsStart = 360;
const _kGoodsStagger = 120;
const _kGoodsPop = 320;
const _kTitle = (start: 860, end: 1180);
const _kTagline = (start: 960, end: 1280);

/// Shows the animated brand splash over [child] once, on cold start, then removes itself.
///
/// Hand-off: Android shows the native launch screen (tomato + empty white basket, same size and position)
/// until Flutter draws its first frame. That first frame is this overlay at t = 0, identical to the native
/// screen. The basket hops, the three goods pop in, the name slides in, and the overlay fades to the app,
/// which has been building (router, first screen, first fetches) underneath the whole time.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_done) SplashScreen(onFinished: _finish),
      ],
    );
  }

  void _finish() {
    // Hand the status bar back to Flutter's default (translucent scrim, light icons); AppBars restyle it.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Color(0x40000000), statusBarIconBrightness: Brightness.light),
    );
    setState(() => _done = true);
  }
}

/// The animated splash itself: tomato background, the basket at the native splash's size and position,
/// goods popping in, then "Jugaad Street" + tagline sliding in from the right, then a fade out.
///
/// With reduced motion ([MediaQueryData.disableAnimations]) it jumps to the composed end frame, holds it
/// briefly and fades quickly.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onFinished});

  /// Called once the fade-out has finished.
  final VoidCallback? onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _kIntroMs));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: _kFadeMs));
  Timer? _hold;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _fade.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _intro.value = 1;
      _hold = Timer(const Duration(milliseconds: 350), () {
        if (mounted) _fade.animateTo(1, duration: const Duration(milliseconds: 120));
      });
    } else {
      _intro.forward().whenComplete(() {
        if (mounted) _fade.forward();
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _intro.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = kSplashArtExtent / 512; // dp per mark unit
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: FadeTransition(
        opacity: ReverseAnimation(_fade),
        child: AbsorbPointer(
          child: Semantics(
            label: 'Jugaad Street',
            container: true,
            child: Material(
              color: AppColors.brand,
              child: LayoutBuilder(builder: (context, box) {
                final centre = Offset(box.maxWidth / 2, box.maxHeight / 2);
                // Text starts under the basket's lowest point (y = 410 in mark units) plus a gap.
                final textTop = centre.dy + (410 - _kVisualCentre.dy) * k + 30;
                return Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(painter: BasketPainter(_intro, extent: kSplashArtExtent, centre: centre)),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: textTop,
                    child: Column(children: [
                      _SlideIn(
                        progress: _interval(_kTitle.start, _kTitle.end),
                        child: const Text(
                          'Jugaad Street',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontFamilyFallback: ['Roboto'],
                            fontWeight: FontWeight.w800,
                            fontSize: 32,
                            height: 1.15,
                            letterSpacing: -0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _SlideIn(
                        progress: _interval(_kTagline.start, _kTagline.end),
                        child: const Text(
                          'Wholesale prices for your whole street',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontFamilyFallback: ['Roboto'],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.35,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Animation<double> _interval(int startMs, int endMs) => CurvedAnimation(
        parent: _intro,
        curve: Interval(startMs / _kIntroMs, endMs / _kIntroMs, curve: Curves.easeOutCubic),
      );
}

/// Fades [child] in while sliding it from the right.
class _SlideIn extends AnimatedWidget {
  const _SlideIn({required Animation<double> progress, required this.child}) : super(listenable: progress);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(56 * (1 - t), 0), child: child),
    );
  }
}

/// Paints mark.svg's basket (handle, three goods, body, weave) with the same geometry, driven by the intro
/// controller [t] (0..1 over [_kIntroMs]): a small hop with a squash on landing, then the goods popping in.
/// The glyph's visual centre is painted at [centre], with the 512-unit art box [extent] dp wide.
class BasketPainter extends CustomPainter {
  BasketPainter(this.t, {required this.extent, required this.centre}) : super(repaint: t);

  final Animation<double> t;
  final double extent;
  final Offset centre;

  static final _handle = Path()
    ..moveTo(136, 252)
    ..cubicTo(136, 52, 376, 52, 376, 252);
  static final _body = Path()
    ..moveTo(108, 250)
    ..lineTo(404, 250)
    ..cubicTo(400, 344, 342, 410, 256, 410)
    ..cubicTo(170, 410, 112, 344, 108, 250)
    ..close();
  static final _weave = Path()
    ..moveTo(136, 300)
    ..cubicTo(200, 318, 312, 318, 376, 300)
    ..moveTo(166, 352)
    ..cubicTo(216, 368, 296, 368, 346, 352);

  /// (centre, radius, colour) in mark.svg order; [_popOrder] is the order they appear in.
  static const _goods = [
    (Offset(194, 240), 34.0, Color(0xFFFFD3C2)),
    (Offset(318, 240), 34.0, Color(0xFFFFD3C2)),
    (Offset(256, 224), 44.0, Color(0xFFFFF1EC)),
  ];
  static const _popOrder = [0, 2, 1]; // left, middle, right

  static final _white = Paint()..color = Colors.white;
  static final _handlePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 26
    ..strokeCap = StrokeCap.round;
  static final _weavePaint = Paint()
    ..color = AppColors.brand
    ..style = PaintingStyle.stroke
    ..strokeWidth = 15
    ..strokeCap = StrokeCap.round;

  static double _seg(double ms, num start, num end) => ((ms - start) / (end - start)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final ms = t.value * _kIntroMs;

    // Hop: rise 26 units (easeOut), fall back (easeIn), then squash on landing and recover.
    final b = _seg(ms, _kBounce.start, _kBounce.end);
    double dy = 0, squash = 0;
    if (b < 0.4) {
      dy = -26 * Curves.easeOut.transform(b / 0.4);
    } else if (b < 0.72) {
      dy = -26 * (1 - Curves.easeIn.transform((b - 0.4) / 0.32));
    } else if (b < 1) {
      squash = math.sin((b - 0.72) / 0.28 * math.pi); // 0 → 1 → 0
    }
    final sy = 1 - 0.07 * squash, sx = 1 + 0.04 * squash;

    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(extent / 512)
      ..translate(-_kVisualCentre.dx, -_kVisualCentre.dy)
      // squash about the basket's base, after the hop
      ..translate(256, 410 + dy)
      ..scale(sx, sy)
      ..translate(-256, -410);

    canvas.drawPath(_handle, _handlePaint);
    for (var i = 0; i < _goods.length; i++) {
      final slot = _popOrder.indexOf(i);
      final start = _kGoodsStart + slot * _kGoodsStagger;
      final p = _seg(ms, start, start + _kGoodsPop);
      if (p <= 0) continue;
      final s = Curves.easeOutBack.transform(p); // small overshoot past 1
      final (c, r, colour) = _goods[i];
      canvas.drawCircle(c, r * s, Paint()..color = colour);
    }
    canvas
      ..drawPath(_body, _white)
      ..drawPath(_weave, _weavePaint)
      ..restore();
  }

  @override
  bool shouldRepaint(BasketPainter old) => old.t != t || old.extent != extent || old.centre != centre;
}
