import 'dart:math';

/// A round number to step an axis by, aiming for roughly four gridlines.
double niceInterval(double span, {required double emptyFallback}) {
  if (span <= 0) return emptyFallback;
  final rough = span / 4;
  final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
  final residual = rough / magnitude;
  final niceResidual = residual >= 5 ? 5.0 : (residual >= 2 ? 2.0 : 1.0);
  return niceResidual * magnitude;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `Jul 6` - short enough to sit under a chart tick.
String shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// `Mon` - DateTime.weekday is 1-based.
String shortWeekday(DateTime date) => _weekdays[date.weekday - 1];
