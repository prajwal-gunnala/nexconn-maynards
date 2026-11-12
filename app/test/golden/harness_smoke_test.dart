@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_street/features/bucket/bucket_detail_screen.dart';
import 'package:jugaad_street/features/home/street_home_screen.dart';

import 'harness.dart';

void main() {
  testWidgets('street home', (t) async => shoot(t, 'smoke_street_home', const StreetHomeScreen()));
  testWidgets('basmati detail', (t) async => shoot(t, 'smoke_bucket_basmati', const BucketDetailScreen(bucketId: 'b_basmati')));
}
