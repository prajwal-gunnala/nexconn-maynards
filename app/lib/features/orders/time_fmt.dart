import 'package:intl/intl.dart';

import '../../core/format.dart';

/// Time display rules shared by create, orders and wallet:
/// times snap to :00 / :30, and "am"/"pm" never wraps away from its number.

const _nbsp = ' ';

/// Nearest :00 or :30, in local time.
DateTime roundHalfHour(DateTime t) {
  final l = t.toLocal();
  final base = DateTime(l.year, l.month, l.day, l.hour);
  return base.add(Duration(minutes: ((l.minute + 15) ~/ 30) * 30));
}

/// `6:00 am` with a non-breaking space.
String timeR(DateTime t) => Fmt.time(roundHalfHour(t)).replaceAll(' ', _nbsp);

/// `Sun 15 Nov · 6:00 am` (rounded, am/pm kept with the number).
String dayTimeR(DateTime t) => '${Fmt.day(roundHalfHour(t))} · ${timeR(t)}';

/// `Fri 5:30 am`: for tight spots like the post-success card.
String shortDayTimeR(DateTime t) => '${DateFormat('EEE').format(roundHalfHour(t))} ${timeR(t)}';

/// One pickup/meet line from the order's own `window` (the server builds it from the bucket's
/// `deliverAt`, or `meet.at` for market buckets), with the date added when we know it:
/// `Sat 14 Nov · 10:00 am–12:00 pm`. [place] is dropped from a trailing "at Gate 3".
String pickupLine({String? window, DateTime? at, String? place}) {
  var w = (window ?? '').trim();
  if (place != null && place.isNotEmpty && w.endsWith(' at $place')) {
    w = w.substring(0, w.length - ' at $place'.length);
  }
  if (w.isEmpty) return at == null ? '' : dayTimeR(at);
  if (at == null) return _glue(w);
  final day = Fmt.day(roundHalfHour(at)); // "Sat 14 Nov"
  final wd = day.substring(0, 3);
  final time = w.startsWith('$wd ') ? w.substring(4) : w;
  final line = w.startsWith('$wd ') ? '$day · $time' : w;
  return _glue(line);
}

String _glue(String s) => s.replaceAllMapped(RegExp(r'(\d) (am|pm)\b'), (m) => '${m[1]}$_nbsp${m[2]}');
