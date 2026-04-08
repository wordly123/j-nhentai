import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingAboutPage extends StatefulWidget {
  const SettingAboutPage({Key? key}) : super(key: key);

  @override
  State<SettingAboutPage> createState() => _SettingAboutPageState();
}

class _SettingAboutPageState extends State<SettingAboutPage> {
  String version = '';
  final String gitRepo = 'https://github.com/wordly123/j-nhentai';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((packageInfo) {
      if (!mounted) {
        return;
      }
      setState(() {
        version = packageInfo.version +
            (packageInfo.buildNumber.isEmpty ? '' : '+${packageInfo.buildNumber}');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('NHentai')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          ListTile(
            title: Text('version'.tr),
            subtitle: Text(version.isEmpty ? '1.0.0+310' : version),
          ),
          ListTile(
            title: const Text('Github'),
            subtitle: SelectableText(gitRepo),
            onTap: () =>
                launchUrlString(gitRepo, mode: LaunchMode.externalApplication),
          ),
        ],
      ).withListTileTheme(context),
    );
  }
}
