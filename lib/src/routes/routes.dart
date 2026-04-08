import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/pages/details/details_page.dart';
import 'package:jhentai/src/pages/details/thumbnails/thumbnails_page.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/pages/download_search/download_search_page.dart';
import 'package:jhentai/src/pages/gallery_image/gallery_image_page.dart';
import 'package:jhentai/src/pages/gallerys/dashboard/dashboard_page.dart';
import 'package:jhentai/src/pages/history/history_page.dart';
import 'package:jhentai/src/pages/gallerys/simple/gallerys_page.dart';
import 'package:jhentai/src/pages/layout/desktop/desktop_home_page.dart';
import 'package:jhentai/src/pages/lock_page.dart';
import 'package:jhentai/src/pages/popular/popular_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page.dart';
import 'package:jhentai/src/pages/read/read_page.dart';
import 'package:jhentai/src/pages/search/mobile_v2/search_page_mobile_v2.dart';
import 'package:jhentai/src/pages/search/quick_search/quick_search_page.dart';
import 'package:jhentai/src/pages/setting/about/setting_about_page.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page.dart';
import 'package:jhentai/src/pages/setting/advanced/setting_advanced_page.dart';
import 'package:jhentai/src/pages/setting/cloud/config_sync/config_sync_page.dart';
import 'package:jhentai/src/pages/setting/cloud/setting_cloud_page.dart';
import 'package:jhentai/src/pages/setting/download/setting_download_page.dart';
import 'package:jhentai/src/pages/setting/nh/setting_nh_page.dart';
import 'package:jhentai/src/pages/setting/preference/setting_preference_page.dart';
import 'package:jhentai/src/pages/setting/read/setting_read_page.dart';
import 'package:jhentai/src/pages/setting/security/setting_security_page.dart';
import 'package:jhentai/src/pages/setting/setting_page.dart';
import 'package:jhentai/src/pages/setting/style/setting_style_page.dart';
import 'package:jhentai/src/pages/home_page.dart';
import 'package:jhentai/src/pages/webview/webview_page.dart';
import 'package:jhentai/src/setting/preference_setting.dart';

import '../pages/blank_page.dart';
import '../pages/details/comment/comment_page.dart';
import '../pages/favorite/favorite_page.dart';
import '../pages/layout/mobile_v2/mobile_layout_page_v2.dart';
import '../pages/search/desktop/desktop_search_page.dart';
import '../pages/setting/account/setting_account_page.dart';
import '../pages/setting/advanced/loglist/log/log_page.dart';
import '../pages/setting/advanced/loglist/log_list_page.dart';
import '../pages/setting/advanced/super_resolution/setting_super_resolution_page.dart';
import '../pages/setting/style/page_list_style/setting_page_list_style_page.dart';
import '../pages/setting/style/theme_color/setting_theme_color_page.dart';
import '../pages/single_image/single_image.dart';
import 'nh_page.dart';

class Routes {
  static const String home = "/";
  static const String lock = "/lock";
  static const String blank = "/blank";

  static const String read = "/read";
  static const String singleImagePage = "/single_image_page";

  /// left
  static const String desktopHome = "/desktop_home";
  static const String mobileLayoutV2 = "/mobile_layout_v2";
  static const String gallerys = "/gallerys";
  static const String dashboard = "/dashboard";
  static const String popular = "/popular";
  static const String ranklist = "/ranklist";
  static const String favorite = "/favorite";
  static const String history = "/history";
  static const String download = "/download";
  static const String setting = "/setting";
  static const String desktopSearch = "/desktop_search";
  static const String mobileV2Search = "/mobile_v2_search";
  static const String downloadSearch = "/download_search";

  /// right
  static const String details = "/details";
  static const String comment = "/comment";
  static const String thumbnails = "/thumbnails";
  static const String webview = "/webview";
  static const String quickSearch = "/qucik_search";
  static const String imagePage = "/image_page";

  static const String settingPrefix = "/setting_";
  static const String settingAccount = "/setting_account";
  static const String settingNH = "/setting_nh";
  static const String settingStyle = "/setting_style";
  static const String settingRead = "/setting_read";
  static const String settingPreference = "/setting_preference";
  static const String settingDownload = "/setting_download";
  static const String settingAdvanced = "/setting_advanced";
  static const String settingCloud = "/setting_cloud";
  static const String settingSecurity = "/setting_security";
  static const String settingAbout = "/setting_about";

  static const String login = "/setting_account/login";

  static const String themeColor = "/setting_style/themeColor";
  static const String pageListStyle = "/setting_style/pageListStyle";

  static const String superResolution = "/setting_advanced/superResolution";
  static const String logList = "/setting_advanced/logList";
  static const String log = "/setting_advanced/logList/log";

  static const String configSync = "/setting_cloud/configSync";

  static final Transition defaultTransition =
      preferenceSetting.enableSwipeBackGesture.isTrue
          ? Transition.cupertino
          : Transition.fadeIn;

  static List<NHPage> pages = <NHPage>[
    NHPage(
      name: home,
      page: () => const HomePage(),
      transition: Transition.fade,
      side: Side.fullScreen,
    ),
    NHPage(
      name: lock,
      page: () => const LockPage(),
      transition: Transition.fade,
      side: Side.fullScreen,
      popGesture: false,
    ),
    NHPage(
      name: blank,
      page: () => const BlankPage(),
      transition: defaultTransition,
      side: Side.right,
    ),
    NHPage(
      name: read,
      page: ReadPage.new,
      transition: defaultTransition,
      side: Side.fullScreen,
    ),
    NHPage(
      name: gallerys,
      page: () => const GallerysPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: dashboard,
      page: () => const DashboardPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: desktopHome,
      page: DesktopHomePage.new,
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: mobileLayoutV2,
      page: MobileLayoutPageV2.new,
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: details,
      page: () => DetailsPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: imagePage,
      page: GalleryImagePage.new,
      transition: defaultTransition,
    ),
    NHPage(
      name: popular,
      page: () => PopularPage(showTitle: true, name: 'popular'.tr),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: ranklist,
      page: () => const RanklistPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: favorite,
      page: () => const FavoritePage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: setting,
      page: () => const SettingPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: history,
      page: HistoryPage.new,
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: download,
      page: () => const DownloadPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: desktopSearch,
      page: () => const DesktopSearchPage(),
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: mobileV2Search,
      page: SearchPageMobileV2.new,
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: downloadSearch,
      page: DownloadSearchPage.new,
      transition: defaultTransition,
      side: Side.left,
    ),
    NHPage(
      name: singleImagePage,
      page: () => const SingleImagePage().withEscOrFifthButton2BackRightRoute(),
      transition: Transition.noTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: webview,
      page: () => const WebviewPage(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: quickSearch,
      page: () => const QuickSearchPage(automaticallyImplyLeading: true)
          .withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: settingAccount,
      page: () =>
          const SettingAccountPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingNH,
      page: () => const SettingNHPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingStyle,
      page: () =>
          const SettingStylePage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingRead,
      page: () => SettingReadPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingPreference,
      page: () =>
          const SettingPreferencePage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingDownload,
      page: () =>
          const SettingDownloadPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingAdvanced,
      page: () =>
          const SettingAdvancedPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingCloud,
      page: () =>
          const SettingCloudPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: configSync,
      page: () => const ConfigSyncPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingSecurity,
      page: () =>
          const SettingSecurityPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: settingAbout,
      page: () =>
          const SettingAboutPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
    ),
    NHPage(
      name: login,
      page: () => LoginPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: themeColor,
      page: () =>
          const SettingThemeColorPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: pageListStyle,
      page: () =>
          SettingPageListStylePage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: superResolution,
      page: () => const SettingSuperResolutionPage()
          .withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: logList,
      page: () => const LogListPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: log,
      page: () => const LogPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: comment,
      page: () => const CommentPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
    NHPage(
      name: thumbnails,
      page: () => ThumbnailsPage().withEscOrFifthButton2BackRightRoute(),
      transition: defaultTransition,
      offAllBefore: false,
    ),
  ];
}
