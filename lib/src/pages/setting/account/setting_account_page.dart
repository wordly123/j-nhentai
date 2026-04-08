import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/setting/user_setting.dart';

import '../../../routes/routes.dart';
import '../../../utils/route_util.dart';
import '../../../widget/nh_log_out_dialog.dart';

class SettingAccountPage extends StatelessWidget {
  const SettingAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('accountSetting'.tr)),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            if (!userSetting.hasAnyAuth()) _buildLogin(),
            if (userSetting.hasAnyAuth()) ...[
              _buildAuthSummary(),
              _buildEditAuth(),
              _buildLogout(context).marginOnly(top: 12),
            ],
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildLogin() {
    return ListTile(
      title: Text('login'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.login),
    );
  }

  Widget _buildAuthSummary() {
    String title = userSetting.displayName ?? 'nhUser'.tr;

    if (userSetting.hasNhAuth()) {
      return ListTile(
        title: Text(title),
        subtitle: Text(
          [
            if (userSetting.nhApiKey.value?.trim().isNotEmpty == true)
              '${'apiKeyLabel'.tr}: ${_mask(userSetting.nhApiKey.value!)}',
          ].join('\n'),
        ),
        isThreeLine: false,
      );
    }

    return ListTile(
      title: Text(title),
      subtitle: Text('legacySessionActive'.tr),
    );
  }

  Widget _buildEditAuth() {
    return ListTile(
      title: Text('editNhAuth'.tr),
      subtitle: Text('updateApiKey'.tr),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => toRoute(Routes.login),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return ListTile(
      title: Text('logout'.tr),
      subtitle:
          Text('youHaveLoggedInAs'.tr + (userSetting.displayName ?? 'nhUser'.tr)),
      onTap: () => Get.dialog(const LogoutDialog()),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        color: UIConfig.alertColor(context),
        onPressed: () => Get.dialog(const LogoutDialog()),
      ),
    );
  }

  String _mask(String raw) {
    String value = raw.trim();
    if (value.length <= 8) {
      return '*' * value.length;
    }

    return '${value.substring(0, 4)}****${value.substring(value.length - 4)}';
  }
}
