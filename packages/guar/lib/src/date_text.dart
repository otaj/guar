// Human-readable date labels shared across screens.

import 'package:guar_domain/guar_domain.dart' as d;

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String formatBeanDate(d.BeanDate date) {
  final int weekday = DateTime(date.year, date.month, date.day).weekday;
  return '${_weekdays[weekday - 1]}, ${_months[date.month - 1]} ${date.day}, ${date.year}';
}
