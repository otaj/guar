// Shared calendar and name-shape checks for parser domain factories.

bool isValidBeanDate(int year, int month, int day) {
  if (year < 1 || year > 9999) return false;
  if (month < 1 || month > 12) return false;
  if (day < 1 || day > daysInMonth(year, month)) return false;
  return true;
}

int daysInMonth(int year, int month) {
  const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && _isLeapYear(year)) return 29;
  return lengths[month - 1];
}

bool _isLeapYear(int year) => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

final RegExp _currencyName = RegExp(
  r"^(?:[A-Z][A-Z0-9'._\-]*[A-Z0-9]?|/[A-Z0-9'._\-]*[A-Z](?:[A-Z0-9'._\-]*[A-Z0-9])?)$",
);

bool isValidCurrencyName(String name) => _currencyName.hasMatch(name);

final RegExp _accountRoot = RegExp(r'^[\p{Lu}][\p{L}\p{Nd}\-]*$', unicode: true);
final RegExp _accountLeaf = RegExp(r'^[\p{Lu}\p{Nd}][\p{L}\p{Nd}\-]*$', unicode: true);

bool isValidAccountName(String name) {
  final parts = name.split(':');
  if (parts.length < 2 || parts.any((part) => part.isEmpty)) return false;
  if (!_accountRoot.hasMatch(parts.first)) return false;
  return parts.skip(1).every(_accountLeaf.hasMatch);
}

bool isValidTagOrLinkName(String name) => name.isNotEmpty && !RegExp(r'\s').hasMatch(name);

bool isValidLetterFlag(String value) => RegExp(r'^[A-Z]$').hasMatch(value);

void ensureBeanDate(int year, int month, int day) {
  if (!isValidBeanDate(year, month, day)) {
    throw ArgumentError.value(
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      'BeanDate',
      'not a valid calendar date',
    );
  }
}

void ensureCurrencyName(String name) {
  if (!isValidCurrencyName(name)) {
    throw ArgumentError.value(name, 'Currency.name', 'not a valid currency code');
  }
}

void ensureAccountName(String name) {
  if (!isValidAccountName(name)) {
    throw ArgumentError.value(name, 'Account.name', 'not a valid account name');
  }
}

void ensureTagOrLinkName(String name, String label) {
  if (!isValidTagOrLinkName(name)) {
    throw ArgumentError.value(name, label, 'must be non-empty and contain no whitespace');
  }
}

void ensureLetterFlag(String value) {
  if (!isValidLetterFlag(value)) {
    throw ArgumentError.value(value, 'Flag.letter', 'must be a single uppercase letter A–Z');
  }
}

void ensureLocationLines(int linenoBegin, int linenoEnd) {
  if (linenoBegin < 0) {
    throw ArgumentError.value(linenoBegin, 'linenoBegin', 'must be >= 0');
  }
  if (linenoEnd < 0) {
    throw ArgumentError.value(linenoEnd, 'linenoEnd', 'must be >= 0');
  }
  if (linenoEnd < linenoBegin) {
    throw ArgumentError.value(linenoEnd, 'linenoEnd', 'must be >= linenoBegin');
  }
}
