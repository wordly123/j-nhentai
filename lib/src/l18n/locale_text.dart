import 'package:get/get.dart';
import 'package:jhentai/src/l18n/zh_CN.dart';

class LocaleText extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'zh_CN': zh_CN.keys(),
      };
}
