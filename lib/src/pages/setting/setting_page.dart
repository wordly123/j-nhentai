import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/routes/routes.dart';
import '../../utils/route_util.dart';
import '../layout/mobile_v2/notification/tap_menu_button_notification.dart';

class SettingPage extends StatelessWidget {
  final bool showMenuButton;

  const SettingPage({Key? key, this.showMenuButton = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('setting'.tr),
        leading: showMenuButton
            ? IconButton(
                icon: const Icon(FontAwesomeIcons.bars, size: 20),
                onPressed: () => TapMenuButtonNotification().dispatch(context))
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text('nhentai'.tr),
            onTap: () => toRoute(Routes.settingNH),
          ),
          ListTile(
            leading: const Icon(Icons.style),
            title: Text('style'.tr),
            onTap: () => toRoute(Routes.settingStyle),
          ),
          ListTile(
            leading: const Icon(Icons.local_library),
            title: Text('read'.tr),
            onTap: () => toRoute(Routes.settingRead),
          ),
          ListTile(
            leading: const Icon(Icons.stars),
            title: Text('preference'.tr),
            onTap: () => toRoute(Routes.settingPreference),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text('download'.tr),
            onTap: () => toRoute(Routes.settingDownload),
          ),
          ListTile(
            leading: const Icon(Icons.settings_suggest),
            title: Text('advanced'.tr),
            onTap: () => toRoute(Routes.settingAdvanced),
          ),
          // ListTile(
          //   leading: const Icon(Icons.cloud),
          //   title: Text('cloud'.tr),
          //   onTap: () => toRoute(Routes.settingCloud),
          // ),
          ListTile(
            leading: const Icon(Icons.security),
            title: Text('security'.tr),
            onTap: () => toRoute(Routes.settingSecurity),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('about'.tr),
            onTap: () => toRoute(Routes.settingAbout),
          ),
        ],
      ),
    );
  }
}
