import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/tab_bar_icon.dart';

import '../../../model/jh_layout.dart';
import '../../../service/tag_translation_service.dart';
import '../../../setting/preference_setting.dart';
import '../../../setting/style_setting.dart';
import '../../../widget/loading_state_indicator.dart';

class SettingPreferencePage extends StatelessWidget {
  const SettingPreferencePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('preferenceSetting'.tr)),
      body: Obx(
        () => SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildLanguageInfo(),
              _buildTagTranslate(),
              _buildDefaultTab(),
              if (styleSetting.isInV2Layout) _buildSimpleDashboardMode(),
              if (styleSetting.isInV2Layout) _buildShowBottomNavigation(),
              if (styleSetting.isInV2Layout ||
                  styleSetting.actualLayout == LayoutMode.desktop)
                _buildHideScroll2TopButton(),
              _buildPreloadGalleryCover(),
              _buildEnableSwipeBackGesture(),
              if (styleSetting.isInV2Layout)
                _buildEnableLeftMenuDrawerGesture(),
              if (styleSetting.isInV2Layout) _buildQuickSearch(),
              if (styleSetting.isInV2Layout)
                _buildDrawerGestureEdgeWidth(context),
              if (GetPlatform.isDesktop && styleSetting.isInDesktopLayout)
                _buildLaunchInFullScreen(),
              _buildTagSearchConfig(),
            ],
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildLanguageInfo() {
    return ListTile(
      title: Text('language'.tr),
      subtitle: const Text('简体中文（固定）'),
    );
  }

  Widget _buildTagTranslate() {
    return ListTile(
      title: Text('enableTagZHTranslation'.tr),
      subtitle: tagTranslationService.loadingState.value == LoadingState.success
          ? Text('${'version'.tr}: ${tagTranslationService.timeStamp.value!}',
              style: const TextStyle(fontSize: 12))
          : tagTranslationService.loadingState.value == LoadingState.loading
              ? Text(
                  '${'downloadTagTranslationHint'.tr}${tagTranslationService.downloadProgress.value}',
                  style: const TextStyle(fontSize: 12),
                )
              : tagTranslationService.loadingState.value == LoadingState.error
                  ? Text('downloadFailed'.tr,
                      style: const TextStyle(fontSize: 12))
                  : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: tagTranslationService.loadingState.value,
            indicatorRadius: 10,
            width: 40,
            idleWidgetBuilder: () => IconButton(
                onPressed: tagTranslationService.fetchDataFromGithub,
                icon: const Icon(Icons.refresh)),
            errorWidgetSameWithIdle: true,
            successWidgetSameWithIdle: true,
          ),
          Switch(
            value: preferenceSetting.enableTagZHTranslation.value,
            onChanged: (value) {
              preferenceSetting.saveEnableTagZHTranslation(value);
              if (value == true &&
                  tagTranslationService.loadingState.value !=
                      LoadingState.success) {
                tagTranslationService.fetchDataFromGithub();
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildDefaultTab() {
    return ListTile(
      title: Text('defaultTab'.tr),
      trailing: DropdownButton<TabBarIconNameEnum>(
        value: preferenceSetting.defaultTab.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (TabBarIconNameEnum? newValue) =>
            preferenceSetting.saveDefaultTab(newValue!),
        items: [
          DropdownMenuItem(
            child: Text(TabBarIconNameEnum.home.name.tr),
            value: TabBarIconNameEnum.home,
          ),
          DropdownMenuItem(
            child: Text(TabBarIconNameEnum.popular.name.tr),
            value: TabBarIconNameEnum.popular,
          ),
          DropdownMenuItem(
            child: Text(TabBarIconNameEnum.ranklist.name.tr),
            value: TabBarIconNameEnum.ranklist,
          ),
          DropdownMenuItem(
            child: Text(TabBarIconNameEnum.favorite.name.tr),
            value: TabBarIconNameEnum.favorite,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDashboardMode() {
    return SwitchListTile(
      title: Text('simpleDashboardMode'.tr),
      subtitle: Text('simpleDashboardModeHint'.tr),
      value: preferenceSetting.simpleDashboardMode.value,
      onChanged: preferenceSetting.saveSimpleDashboardMode,
    );
  }

  Widget _buildShowBottomNavigation() {
    return SwitchListTile(
      title: Text('hideBottomBar'.tr),
      value: preferenceSetting.hideBottomBar.value,
      onChanged: preferenceSetting.saveHideBottomBar,
    );
  }

  Widget _buildHideScroll2TopButton() {
    return ListTile(
      title: Text('hideScroll2TopButton'.tr),
      trailing: DropdownButton<Scroll2TopButtonModeEnum>(
        value: preferenceSetting.hideScroll2TopButton.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (Scroll2TopButtonModeEnum? newValue) =>
            preferenceSetting.saveHideScroll2TopButton(newValue!),
        items: [
          DropdownMenuItem(
            child: Text('whenScrollUp'.tr),
            value: Scroll2TopButtonModeEnum.scrollUp,
          ),
          DropdownMenuItem(
            child: Text('whenScrollDown'.tr),
            value: Scroll2TopButtonModeEnum.scrollDown,
          ),
          DropdownMenuItem(
            child: Text('never'.tr),
            value: Scroll2TopButtonModeEnum.never,
          ),
          DropdownMenuItem(
            child: Text('always'.tr),
            value: Scroll2TopButtonModeEnum.always,
          ),
        ],
      ),
    );
  }

  Widget _buildPreloadGalleryCover() {
    return SwitchListTile(
      title: Text('preloadGalleryCover'.tr),
      subtitle: Text('preloadGalleryCoverHint'.tr),
      value: preferenceSetting.preloadGalleryCover.value,
      onChanged: preferenceSetting.savePreloadGalleryCover,
    );
  }

  Widget _buildEnableSwipeBackGesture() {
    return SwitchListTile(
      title: Text('enableSwipeBackGesture'.tr),
      subtitle: Text('needRestart'.tr),
      value: preferenceSetting.enableSwipeBackGesture.value,
      onChanged: preferenceSetting.saveEnableSwipeBackGesture,
    );
  }

  Widget _buildEnableLeftMenuDrawerGesture() {
    return SwitchListTile(
      title: Text('enableLeftMenuDrawerGesture'.tr),
      value: preferenceSetting.enableLeftMenuDrawerGesture.value,
      onChanged: preferenceSetting.saveEnableLeftMenuDrawerGesture,
    );
  }

  Widget _buildQuickSearch() {
    return SwitchListTile(
      title: Text('enableQuickSearchDrawerGesture'.tr),
      value: preferenceSetting.enableQuickSearchDrawerGesture.value,
      onChanged: preferenceSetting.saveEnableQuickSearchDrawerGesture,
    );
  }

  Widget _buildDrawerGestureEdgeWidth(BuildContext context) {
    return ListTile(
      title: Text('drawerGestureEdgeWidth'.tr),
      trailing: Obx(() {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderTheme.of(context)
                  .copyWith(showValueIndicator: ShowValueIndicator.onDrag),
              child: Slider(
                min: 20,
                max: 300,
                label:
                    preferenceSetting.drawerGestureEdgeWidth.value.toString(),
                value:
                    preferenceSetting.drawerGestureEdgeWidth.value.toDouble(),
                onChanged: (value) {
                  preferenceSetting.drawerGestureEdgeWidth.value =
                      value.toInt();
                },
                onChangeEnd: (value) {
                  preferenceSetting.saveDrawerGestureEdgeWidth(value.toInt());
                },
              ),
            ),
          ],
        );
      }),
    );
  }


  Widget _buildLaunchInFullScreen() {
    return SwitchListTile(
      title: Text('launchInFullScreen'.tr),
      subtitle: Text('launchInFullScreenHint'.tr),
      value: preferenceSetting.launchInFullScreen.value,
      onChanged: preferenceSetting.saveLaunchInFullScreen,
    );
  }

  Widget _buildTagSearchConfig() {
    return ListTile(
      title: Text('searchBehaviour'.tr),
      subtitle: Text(
        preferenceSetting.searchBehaviour.value == SearchBehaviour.inheritAll
            ? 'inheritAllHint'.tr
            : preferenceSetting.searchBehaviour.value ==
                    SearchBehaviour.inheritPartially
                ? 'inheritPartiallyHint'.tr
                : 'noneHint'.tr,
      ),
      trailing: DropdownButton<SearchBehaviour>(
        value: preferenceSetting.searchBehaviour.value,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (SearchBehaviour? newValue) =>
            preferenceSetting.saveTagSearchConfig(newValue!),
        items: [
          DropdownMenuItem(
            child: Text('inheritAll'.tr),
            value: SearchBehaviour.inheritAll,
          ),
          DropdownMenuItem(
            child: Text('inheritPartially'.tr),
            value: SearchBehaviour.inheritPartially,
          ),
          DropdownMenuItem(
            child: Text('none'.tr),
            value: SearchBehaviour.none,
          ),
        ],
      ),
    );
  }
}
