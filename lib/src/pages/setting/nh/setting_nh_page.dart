import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/locale_consts.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingNHPage extends StatelessWidget {
  const SettingNHPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('nhentai'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            ListTile(
              title: Text('account'.tr),
              subtitle: Text(userSetting.hasAnyAuth()
                  ? (userSetting.displayName ?? 'nhUser'.tr)
                  : 'tap2Login'.tr),
              trailing: const Icon(Icons.keyboard_arrow_right),
              onTap: () => toRoute(Routes.login),
            ),
            ListTile(
              title: Text('nhentaiSearchLanguage'.tr),
              subtitle: Text('nhentaiSearchLanguageHint'.tr),
              trailing: DropdownButton<String?>(
                value: preferenceSetting.nhentaiSearchLanguage.value,
                menuMaxHeight: 240,
                onChanged: preferenceSetting.saveNhentaiSearchLanguage,
                items: [
                  DropdownMenuItem(value: null, child: Text('nope'.tr)),
                  ...LocaleConsts.language2Abbreviation.keys.map(
                    (language) => DropdownMenuItem(
                      value: language,
                      child: Text(language.capitalizeFirst!),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text('nhentaiApiDocs'.tr),
              subtitle: const Text('https://nhentai.net/api/v2/docs'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrlString('https://nhentai.net/api/v2/docs'),
            ),
          ],
        ).withListTileTheme(context),
      ),
    );
  }
}
