// Shared screenshot harness for feature screens (owned by the lead — don't edit; copy helpers locally if needed).
//
// Renders a screen at phone size with the real theme, bundled fonts, real providers and fixture-backed HTTP
// (test/fixtures/*.json, recorded from the running server as Ananya, B-1204, Sea Breeze Towers).
//
//   testWidgets('basmati detail', (t) async {
//     await shoot(t, 'bucket_bulk', const BucketDetailScreen(bucketId: 'b_basmati'));
//   });
//
// Run:  flutter test test/golden/<file>_test.dart --update-goldens
// PNGs: test/golden/shots/<name>.png  (1080×2400, i.e. 412×915 logical at 2.625 dpr). LOOK at them.
import 'dart:convert';
import 'dart:io';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart' show EngineProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jugaad_street/core/api/api_client.dart';
import 'package:jugaad_street/core/nexconn/chat_session.dart';
import 'package:jugaad_street/core/nexconn/nexconn_service.dart';
import 'package:jugaad_street/core/session/session_store.dart';
import 'package:jugaad_street/core/theme/app_theme.dart';

const phoneSize = Size(412, 915);
const phoneDpr = 2.625;

String get _sdkFonts =>
    '${Platform.environment['FLUTTER_ROOT'] ?? '/home/prajwal/Documents/flutter'}/bin/cache/artifacts/material_fonts';

bool _fontsLoaded = false;

/// Bundled Plus Jakarta Sans + Roboto (fallback, has ₹) + Material icons, so shots show real text, not boxes.
Future<void> loadFonts() async {
  if (_fontsLoaded) return;
  final pjs = FontLoader('PlusJakartaSans');
  for (final w in [400, 500, 600, 700, 800]) {
    pjs.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await pjs.load();
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(_file('$_sdkFonts/Roboto-$f.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(_file('$_sdkFonts/MaterialIcons-Regular.otf'))).load();
  _fontsLoaded = true;
}

Future<ByteData> _file(String path) async => ByteData.sublistView(await File(path).readAsBytes());

dynamic fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

/// HTTP backed by fixtures. [overrides] maps "METHOD /api/path" (or "/api/path" for GET) to a JSON-able body.
MockClient fixtureHttp({Map<String, Object?> overrides = const {}}) {
  return MockClient((req) async {
    final path = req.url.path;
    final key = '${req.method} $path';
    Object? body;
    if (overrides.containsKey(key)) {
      body = overrides[key];
    } else if (req.method == 'GET' && overrides.containsKey(path)) {
      body = overrides[path];
    } else {
      body = _route(req.method, path);
    }
    if (body == null) {
      return http.Response(jsonEncode({'error': {'code': 'NOT_FOUND', 'message': 'No fixture for $key'}}), 404);
    }
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Object? _route(String method, String path) {
  final seg = path.split('/').where((s) => s.isNotEmpty).toList(); // ['api', ...]
  if (method == 'GET') {
    if (path == '/api/me') return fixture('me');
    if (path == '/api/me/wallet') return fixture('wallet');
    if (path == '/api/me/orders') return fixture('orders');
    if (path == '/api/vendor/dashboard') return fixture('vendor_dashboard');
    if (path == '/api/health') return {'ok': true, 'nexconn': 'ok'};
    if (seg.length == 3 && seg[1] == 'communities') return fixture('community');
    if (seg.length == 4 && seg[1] == 'communities' && seg[3] == 'buckets') return fixture('buckets');
    if (seg.length == 2 && seg[1] == 'communities') return [fixture('community')];
    if (seg.length == 3 && seg[1] == 'buckets') {
      final f = File('test/fixtures/bucket_${seg[2]}.json');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }
    if (seg.length == 3 && seg[1] == 'orders') {
      final orders = (fixture('orders') as List).cast<Map<String, dynamic>>();
      return orders.where((o) => o['id'] == seg[2]).firstOrNull ?? (orders.isEmpty ? null : orders.first);
    }
    if (seg.length == 4 && seg[1] == 'admin') return fixture('admin');
  }
  return null;
}

/// Pumps [screen] inside the real theme + providers and writes test/golden/shots/NAME.png.
/// Use [overrides] to fake POST results or alternative states. [wrapInRouter] gives the screen a GoRouter
/// so context.push/pop work (pushes land on a blank page).
Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Map<String, Object?> overrides = const {},
  Future<void> Function(WidgetTester t)? act,
  bool wrapInRouter = true,
}) async {
  await tester.runAsync(loadFonts);
  tester.view.physicalSize = phoneSize * phoneDpr;
  tester.view.devicePixelRatio = phoneDpr;
  addTearDown(tester.view.reset);

  final me = fixture('me') as Map<String, dynamic>;
  final community = fixture('community') as Map<String, dynamic>;
  SharedPreferences.setMockInitialValues({
    'session.token': 'test-session',
    'session.user': jsonEncode(me['user']),
    'session.community': jsonEncode(community),
    'session.unit': 'B-1204',
    'session.role': 'member',
    'session.onboarded': true,
  });
  final api = ApiClient(baseUrl: 'http://test', httpClient: fixtureHttp(overrides: overrides));
  final session = (await tester.runAsync(() => SessionStore.open(api)))!;
  final nexconn = NexconnService(EngineProvider());
  final chat = ChatSession(session, nexconn);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/:rest(.*)', builder: (_, s) => Scaffold(body: Center(child: Text('pushed ${s.uri}')))),
  ]);

  final themed = MultiProvider(
    providers: [
      Provider.value(value: api),
      ChangeNotifierProvider.value(value: session),
      Provider.value(value: nexconn),
      Provider.value(value: chat),
    ],
    child: wrapInRouter
        ? MaterialApp.router(debugShowCheckedModeBanner: false, theme: AppTheme.light(), routerConfig: router)
        : MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light(), home: screen),
  );

  await tester.runAsync(() async {
    await tester.pumpWidget(themed);
    // let fixture futures + image decoding settle
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _precacheImages(tester);
  });
  await tester.pump(const Duration(milliseconds: 400));
  if (act != null) {
    await act(tester);
    await tester.pump(const Duration(milliseconds: 600));
  }
  await expectLater(find.byWidget(themed).first, matchesGoldenFile('shots/$name.png'));
}

Future<void> _precacheImages(WidgetTester tester) async {
  for (final el in find.byType(Image).evaluate()) {
    final img = el.widget as Image;
    await precacheImage(img.image, el, onError: (_, _) {});
  }
  await tester.pump();
}
