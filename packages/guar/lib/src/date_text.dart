// Human-readable date labels shared across screens.

import 'package:guar_domain/guar_domain.dart' as d;
import 'package:intl/intl.dart';

String formatBeanDate(d.BeanDate date, String locale) =>
    DateFormat.yMMMMEEEEd(locale).format(DateTime(date.year, date.month, date.day));
