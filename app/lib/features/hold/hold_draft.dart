import '../../core/models/models.dart';
import '../bucket/detail_model.dart';

/// What the detail screen hands to `/bucket/:id/hold`. The route only carries
/// the id, so the pick travels through this small holder (or the HoldScreen
/// `request` parameter in tests).
class HoldRequest {
  const HoldRequest({required this.view, required this.draft, this.pendingShare});

  final BucketView view;
  final JoinDraft draft;

  /// An existing `pending_payment` share to finish instead of creating one.
  final Share? pendingShare;

  static final Map<String, HoldRequest> _pending = {};

  static void put(HoldRequest r) => _pending[r.view.bucket.id] = r;

  static HoldRequest? take(String bucketId) => _pending.remove(bucketId);
}
