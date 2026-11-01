import '../format.dart';

/// Waste / neutral / productive totals for one day.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.wasted,
    required this.neutral,
    required this.productive,
  });

  final DateTime date;
  final int wasted;
  final int neutral;
  final int productive;

  int get total => wasted + neutral + productive;
  int get dayKey => dayKeyOf(date);
}
