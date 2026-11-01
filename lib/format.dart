import 'package:flutter/material.dart';

import 'theme.dart';

/// "4h 33m", "52m", "0m"
String dur(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '${r}m';
  if (r == 0) return '${h}h';
  return '${h}h ${r}m';
}

/// "34h 39m" with thousands separators for the big yearly numbers.
String durLong(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  final h = m ~/ 60;
  final r = m % 60;
  final hs = thousands(h);
  if (h == 0) return '${r}m';
  if (r == 0) return '${hs}h';
  return '${hs}h ${r}m';
}

/// Two-character monogram for a widget app badge: "Instagram" -> "In".
String widgetInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  final first = words.first;
  if (first.length == 1) return first.toUpperCase();
  return first[0].toUpperCase() + first[1].toLowerCase();
}

String thousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

/// "2h 40m" style but compact for chart labels: "5:06".
String hmmColon(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String weekdayShort(DateTime d) => _weekdays[d.weekday - 1].substring(0, 1);
String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// "19–25 Oct"
String weekSpan(List<DateTime> days) {
  if (days.isEmpty) return '';
  final a = days.first;
  final b = days.last;
  if (a.month == b.month) return '${a.day}–${b.day} ${_months[a.month - 1]}';
  return '${a.day} ${_months[a.month - 1]}–${b.day} ${_months[b.month - 1]}';
}

String clockLabel(int minutesOfDay) {
  final h = (minutesOfDay ~/ 60) % 24;
  final m = minutesOfDay % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int dayKeyOf(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Shifts a date by calendar days without DST duration drift.
DateTime dayOffset(DateTime d, int offsetDays) =>
    DateTime(d.year, d.month, d.day + offsetDays);

DateTime dateFromKey(int key) =>
    DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);

int minutesInHours(int hours) => hours * 60;

/// Palette for a category.
Color tagColor(AppTag tag) => switch (tag) {
      AppTag.wasted => C.orange,
      AppTag.neutral => C.muted,
      AppTag.productive => C.lime,
    };

Color tagBarColor(AppTag tag) => switch (tag) {
      AppTag.wasted => C.orange,
      AppTag.neutral => C.neutral,
      AppTag.productive => C.lime,
    };

enum AppTag { wasted, neutral, productive }

extension AppTagX on AppTag {
  String get label => switch (this) {
        AppTag.wasted => 'Wasted',
        AppTag.neutral => 'Neutral',
        AppTag.productive => 'Productive',
      };

  String get upper => label.toUpperCase();

  AppTag get next => switch (this) {
        AppTag.wasted => AppTag.neutral,
        AppTag.neutral => AppTag.productive,
        AppTag.productive => AppTag.wasted,
      };

  static AppTag parse(String? s) {
    switch (s) {
      case 'productive':
        return AppTag.productive;
      case 'wasted':
        return AppTag.wasted;
      default:
        return AppTag.neutral;
    }
  }
}
