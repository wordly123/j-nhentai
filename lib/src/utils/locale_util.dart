import 'dart:ui';

Locale localeCode2Locale(String localeCode) {
  // Single-language build: force all locale configs to zh_CN.
  return const Locale('zh', 'CN');
}

Locale computeDefaultLocale(Locale windowLocale) {
  return const Locale('zh', 'CN');
}
