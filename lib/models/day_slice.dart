import '../format.dart';
import 'app_meta.dart';

/// One app's slice of a single day.
class DaySlice {
  const DaySlice({
    required this.meta,
    required this.minutes,
    required this.tag,
  });

  final AppMeta meta;
  final int minutes;
  final AppTag tag;
}
