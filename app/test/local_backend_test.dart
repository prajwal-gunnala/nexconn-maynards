import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/core/api/api_client.dart';
import 'package:jugaad_street/core/api/local_backend.dart';
import 'package:jugaad_street/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ApiClient> login(String phone, {String? name}) async {
    final api = ApiClient(baseUrl: 'http://local.jugaad', httpClient: await LocalBackend.load());
    final r = await api.verifyOtp(phone, '1234', name: name);
    api.token = r.sessionToken;
    return api;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Ananya: claim a seer part, hold, wallet; then fill it and capture', () async {
    final api = await login('9000000001');
    final me = await api.me();
    expect(me.user.name, 'Ananya');
    final live = await api.buckets('c_seabreeze');
    expect(live, isNotEmpty);
    final raw = await api.get('/api/buckets/b_seer') as Map;
    final open = (raw['units'] as List).where((u) => u['owner'] == null).map((u) => u['id'] as String).toList();
    expect(open, isNotEmpty);
    final before = await api.wallet();
    final r = await api.addShare('b_seer', payMode: PayMode.hold, unitIds: [open.first]);
    expect(r.share!.hold, isNotNull);
    final held = await api.authorizeHold(r.share!.hold!.id, vpa: 'ananya@okaxis', pin: '1234');
    expect(held.share!.status.toString(), contains('held'));
    final after = await api.wallet();
    expect(after.heldNow, greaterThan(before.heldNow));
    // Cutoff time is shifted to stay in the future.
    final b = await api.bucket('b_seer');
    expect(b.cutoffAt!.isAfter(DateTime.now()), isTrue);
    // Leave and claim everything open → locks into an order with my OTP.
    await api.leaveShare(held.share!.id);
    final r2 = await api.addShare('b_seer', payMode: PayMode.hold, unitIds: open);
    final done = await api.authorizeHold(r2.share!.hold!.id, vpa: 'ananya@okaxis', pin: '1234');
    expect(done.share!.otp, isNotNull);
    expect((await api.myOrders()).first.bucketId, 'b_seer');
    final vendor = await login('9000000012');
    expect((await vendor.vendorDashboard())['vendor'], isNotNull);
    final murugan = await login('9000000011');
    final dash = await murugan.vendorDashboard();
    expect(dash['vendor'], isNotNull);
    final ordered = await murugan.get('/api/orders/JS-6687') as Map;
    expect(ordered['lines'], isNotEmpty);
    final o = await murugan.handover('JS-6687', '9535');
    expect(o.lines.firstWhere((l) => l.userId == 'u_ananya').collected, isTrue);
    final admin = await login('9000000005');
    expect((await admin.adminCommunity('c_seabreeze'))['nudges'], isA<List>());
  });

  test('new phone needs a name, then joins a community', () async {
    final api = ApiClient(baseUrl: 'http://local.jugaad', httpClient: await LocalBackend.load());
    await expectLater(api.verifyOtp('9876543210', '1234'), throwsA(isA<ApiException>()));
    final r = await api.verifyOtp('9876543210', '1234', name: 'Neha');
    api.token = r.sessionToken;
    expect(r.nexconn.token, isNotEmpty);
    expect((await api.me()).memberships, isEmpty);
    await api.joinCommunity('c_seabreeze', unit: 'd-101');
    expect((await api.me()).memberships.single.unit, 'D-101');
    final cut = DateTime.now().add(const Duration(hours: 5));
    final created = await api.createBucket({
      'communityId': 'c_seabreeze', 'type': 'bulk', 'title': 'Test rice', 'category': 'grocery',
      'cutoffAt': cut.toIso8601String(), 'tiers': [{'minQty': 10, 'unitPrice': 90}], 'unitLabel': 'kg',
    });
    expect(created.cutoffAt!.difference(cut).inMinutes.abs(), lessThan(2));
    final bs = await api.buckets('c_seabreeze');
    expect(bs.any((b) => b.id == created.id), isTrue);
    final bulk = bs.firstWhere((b) => b.id == 'b_basmati');
    final r2 = await api.addShare(bulk.id, payMode: PayMode.hold, qty: 5);
    await api.authorizeHold(r2.share!.hold!.id, vpa: 'neha@okaxis', pin: '1234');
    expect((await api.wallet()).heldNow, greaterThan(0));
  });
}
