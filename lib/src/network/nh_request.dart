import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_socks_proxy/socks_proxy.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/get_utils/src/platform/platform.dart';
import 'package:intl/intl.dart';
import 'package:j_downloader/j_downloader.dart';
import 'package:jhentai/src/consts/nh_consts.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/nh_site_exception.dart';
import 'package:jhentai/src/model/detail_page_info.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/model/gallery_count.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/nh_raw_tag.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/network/nh_ip_provider.dart';
import 'package:jhentai/src/network/nh_timeout_translator.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/nh_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/nh_spider_parser.dart';
import 'package:jhentai/src/utils/proxy_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:path/path.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewCookieManager;
import '../service/jh_service.dart';
import '../service/local_config_service.dart';
import '../setting/network_setting.dart';
import 'nh_cache_manager.dart';
import 'nh_cookie_manager.dart';

EHRequest ehRequest = EHRequest();

class EHRequest with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final Dio _dio;
  late final EHCookieManager _cookieManager;
  late final EHCacheManager _cacheManager;
  late final EHIpProvider _ehIpProvider;
  late final String systemProxyAddress;
  final Map<int, Map<String, dynamic>> _nhTagCache = {};
  final Map<int, String> _nhTagZhMap = {};
  Future<void>? _nhTagZhLoadingTask;
  List<String> _nhentaiImageServers = const ['https://i.nhentai.net'];
  List<String> _nhentaiThumbServers = const ['https://t.nhentai.net'];

  List<Cookie> get cookies => List.unmodifiable(_cookieManager.cookies);

  static const String domainFrontingExtraKey = 'JHDF';
  static const String _nhentaiApiBase = 'https://nhentai.net/api/v2';
  static const int _nhentaiThumbsPerPage = 40;
  static const String _nhentaiTagZhAssetPath = 'assets/nhentai/tag_zh_cn.json';
  static const String _nhentaiUserAgent = 'NHentaiApp/1.0 (JHenTai Fork)';
  static const int _nhentai429RetryTimes = 2;

  bool get isNhentaiMode => true;

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..addAll([networkSetting, ehSetting]);

  @override
  Future<void> doInitBean() async {
    _dio = Dio(BaseOptions(
      connectTimeout:
          Duration(milliseconds: networkSetting.connectTimeout.value),
      receiveTimeout:
          Duration(milliseconds: networkSetting.receiveTimeout.value),
    ));

    systemProxyAddress = await getSystemProxyAddress();
    await _initProxy();

    await _initCookieManager();

    _initCacheManager();

    _initDomainFronting();
    _initCertificateForAndroidWithOldVersion();

    _ehIpProvider = RoundRobinIpProvider(NetworkSetting.host2IPs);

    _initTimeOutTranslator();
    await _initNhentaiCdnConfig();

    ever(ehSetting.site, (_) {
      _cookieManager.removeCookies(['sp']);
    });
    ever(networkSetting.connectTimeout, (_) {
      setConnectTimeout(networkSetting.connectTimeout.value);
    });
    ever(networkSetting.receiveTimeout, (_) {
      setReceiveTimeout(networkSetting.receiveTimeout.value);
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> _initProxy() async {
    SocksProxy.initProxy(
      onCreate: (client) =>
          client.badCertificateCallback = (_, String host, __) {
        return networkSetting.allIPs.contains(host);
      },
      findProxy: await findProxySettingFunc(() => systemProxyAddress),
    );
  }

  Future<void> _initCookieManager() async {
    _cookieManager = EHCookieManager(localConfigService);
    await _cookieManager.initCookies();
    _dio.interceptors.add(_cookieManager);
  }

  void _initCacheManager() {
    _cacheManager = EHCacheManager(
      options: CacheOptions(
        policy: CachePolicy.disable,
        expire: networkSetting.pageCacheMaxAge.value,
        store: SqliteCacheStore(appDb: appDb),
      ),
    );
    _dio.interceptors.add(_cacheManager);
  }

  void _initDomainFronting() {
    /// domain fronting interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
        if (networkSetting.enableDomainFronting.isFalse) {
          handler.next(options);
          return;
        }

        String rawPath = options.path;
        String host = options.uri.host;
        if (!_ehIpProvider.supports(host)) {
          handler.next(options);
          return;
        }

        String ip = _ehIpProvider.nextIP(host);
        handler.next(options.copyWith(
          path: rawPath.replaceFirst(host, ip),
          headers: {...options.headers, 'host': host},
          extra: options.extra
            ..[domainFrontingExtraKey] = {'host': host, 'ip': ip},
        ));
      },
      onError: (DioException e, ErrorInterceptorHandler handler) {
        if (!e.requestOptions.extra.containsKey(domainFrontingExtraKey)) {
          handler.next(e);
          return;
        }

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.badResponse ||
            e.type == DioExceptionType.connectionError) {
          String host = e.requestOptions.extra[domainFrontingExtraKey]['host'];
          String ip = e.requestOptions.extra[domainFrontingExtraKey]['ip'];
          _ehIpProvider.addUnavailableIp(host, ip);
          log.info('Add unavailable host-ip: $host-$ip');
        }

        handler.next(e);
      },
    ));
  }

  /// https://github.com/dart-lang/io/issues/83
  void _initCertificateForAndroidWithOldVersion() {
    if (GetPlatform.isAndroid) {
      const isrgRootX1 = '''-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
''';
      SecurityContext.defaultContext.setTrustedCertificatesBytes(
          Uint8List.fromList(isrgRootX1.codeUnits));
    }
  }

  void _initTimeOutTranslator() {
    _dio.interceptors.add(EHTimeoutTranslator());
  }

  Future<void> _initNhentaiCdnConfig() async {
    try {
      Response response = await _getWithErrorHandler(
        '$_nhentaiApiBase/cdn',
        options: CacheOptions.cacheOptions.toOptions(),
      );

      Map<String, dynamic> data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {};

      List<String> imageServers =
          (data['image_servers'] as List? ?? const <dynamic>[])
              .map((server) => server.toString().trim())
              .where((server) => server.isNotEmpty)
              .toList();
      List<String> thumbServers =
          (data['thumb_servers'] as List? ?? const <dynamic>[])
              .map((server) => server.toString().trim())
              .where((server) => server.isNotEmpty)
              .toList();

      if (imageServers.isNotEmpty) {
        _nhentaiImageServers = imageServers;
      }
      if (thumbServers.isNotEmpty) {
        _nhentaiThumbServers = thumbServers;
      }
    } catch (e, s) {
      log.error('Load nhentai cdn config failed', e, s);
    }
  }

  Future<void> storeEHCookies(List<Cookie> cookies) {
    return _cookieManager.storeEHCookies(cookies);
  }

  Future<bool> removeAllCookies() {
    return _cookieManager.removeAllCookies();
  }

  Future<void> removeCacheByUrl(String url) {
    return _cacheManager.removeCacheByUrl(url);
  }

  Future<void> removeCacheByGalleryUrlAndPage(
      String galleryUrl, int pageIndex) {
    Uri uri = Uri.parse(galleryUrl);
    uri = uri.replace(queryParameters: {'p': pageIndex.toString()});

    List<Future> futures = [];
    futures.add(removeCacheByUrlPrefix(uri.toString()));

    NetworkSetting.host2IPs[uri.host]?.forEach((ip) {
      futures.add(removeCacheByUrlPrefix(uri.replace(host: ip).toString()));
    });

    return Future.wait(futures);
  }

  Future<void> removeCacheByUrlPrefix(String url) {
    return _cacheManager.removeCacheByUrlPrefix(url);
  }

  Future<void> removeAllCache() {
    return _cacheManager.removeAllCache();
  }

  ProxyConfig? currentProxyConfig() {
    switch (networkSetting.proxyType.value) {
      case JProxyType.system:
        if (systemProxyAddress.trim().isEmpty) {
          return null;
        }
        return ProxyConfig(
          type: ProxyType.http,
          address: systemProxyAddress,
        );
      case JProxyType.http:
        return ProxyConfig(
          type: ProxyType.http,
          address: networkSetting.proxyAddress.value,
          username: networkSetting.proxyUsername.value,
          password: networkSetting.proxyPassword.value,
        );
      case JProxyType.socks5:
        return ProxyConfig(
          type: ProxyType.socks5,
          address: networkSetting.proxyAddress.value,
          username: networkSetting.proxyUsername.value,
          password: networkSetting.proxyPassword.value,
        );
      case JProxyType.socks4:
        return ProxyConfig(
          type: ProxyType.socks4,
          address: networkSetting.proxyAddress.value,
          username: networkSetting.proxyUsername.value,
          password: networkSetting.proxyPassword.value,
        );
      case JProxyType.direct:
        return ProxyConfig(
          type: ProxyType.direct,
          address: '',
        );
    }
  }

  void setConnectTimeout(int connectTimeout) {
    _dio.options.connectTimeout = Duration(milliseconds: connectTimeout);
  }

  void setReceiveTimeout(int receiveTimeout) {
    _dio.options.receiveTimeout = Duration(milliseconds: receiveTimeout);
  }

  Future<T> requestLogin<T>(
      String userName, String passWord, HtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EForums,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {'act': 'Login', 'CODE': '01'},
      data: {
        'referer': 'https://forums.e-hentai.org/index.php?',
        'b': '',
        'bt': '',
        'UserName': userName,
        'PassWord': passWord,
        'CookieDate': 365,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<void> requestLogout() async {
    await removeAllCookies();
    await userSetting.clearBeanConfig();
    if (GetPlatform.isWindows || GetPlatform.isLinux) {
      Directory directory = Directory(join(pathService.getVisibleDir().path,
          EHConsts.desktopWebviewDirectoryName));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } else {
      await WebViewCookieManager().clearCookies();
    }
  }

  Future<T> requestHomePage<T>({HtmlParser<T>? parser}) async {
    Response response = await _getWithErrorHandler(EHConsts.EHome);
    return _parseResponse(response, parser);
  }

  Future<T> requestNews<T>(HtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(EHConsts.ENews);
    return _parseResponse(response, parser);
  }

  Future<T> requestForum<T>(int ipbMemberId, HtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(
      EHConsts.EForums,
      queryParameters: {
        'showuser': ipbMemberId,
      },
    );
    return _parseResponse(response, parser);
  }

  /// [url]: used for file search
  Future<T> requestGalleryPage<T>({
    String? url,
    String? prevGid,
    String? nextGid,
    DateTime? seek,
    SearchConfig? searchConfig,
    required HtmlParser<T> parser,
  }) async {
    if (isNhentaiMode) {
      return await _requestNhentaiGalleryPage(
        url: url,
        prevGid: prevGid,
        nextGid: nextGid,
        searchConfig: searchConfig,
      ) as T;
    }

    Response response = await _getWithErrorHandler(
      url ?? searchConfig!.toPath(),
      queryParameters: {
        if (prevGid != null) 'prev': prevGid,
        if (nextGid != null) 'next': nextGid,
        if (seek != null) 'seek': DateFormat('yyyy-MM-dd').format(seek),
        ...?searchConfig?.toQueryParameters(),
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestDetailPage<T>({
    required String galleryUrl,
    int thumbnailsPageIndex = 0,
    bool useCacheIfAvailable = true,
    CancelToken? cancelToken,
    required HtmlParser<T> parser,
  }) async {
    if (isNhentaiMode) {
      int? gid = _extractNhentaiGid(galleryUrl);
      if (gid != null) {
        if (identical(parser, EHSpiderParser.detailPage2Comments)) {
          List<GalleryComment> comments = await _requestNhentaiComments(gid);
          return comments as T;
        }

        Map<String, dynamic> galleryMap =
            await _requestNhentaiGalleryDetailMap(gid);

        if (identical(parser, EHSpiderParser.detailPage2Thumbnails)) {
          return _nhentaiBuildThumbnails(
              galleryMap['pages'] as List? ?? [], thumbnailsPageIndex) as T;
        }

        if (identical(parser, EHSpiderParser.detailPage2RangeAndThumbnails)) {
          return _nhentaiBuildDetailPageInfo(galleryMap, thumbnailsPageIndex)
              as T;
        }

        ({GalleryDetail galleryDetails, String apikey}) detailPageInfo = (
          galleryDetails: await _nhentaiDetailMap2GalleryDetail(
              galleryMap, thumbnailsPageIndex),
          apikey: '',
        );
        return detailPageInfo as T;
      }
    }

    Response response = await _getWithErrorHandler(
      galleryUrl,
      queryParameters: {
        'p': thumbnailsPageIndex,

        /// show all comments
        'hc': preferenceSetting.showAllComments.isTrue ? 1 : 0,
      },
      cancelToken: cancelToken,
      options: useCacheIfAvailable
          ? CacheOptions.cacheOptions.toOptions()
          : CacheOptions.noCacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestGalleryMetadata<T>({
    required int gid,
    required String token,
    required HtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHApi,
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'method': 'gdata',
        'gidlist': [
          [gid, token]
        ],
        "namespace": 1,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestGalleryMetadatas<T>({
    required List<({int gid, String token})> list,
    required HtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHApi,
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'method': 'gdata',
        'gidlist': list.map((item) => [item.gid, item.token]).toList(),
        "namespace": 1,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestRanklistPage<T>(
      {required RanklistType ranklistType,
      required int pageNo,
      String? searchQuery,
      required HtmlParser<T> parser}) async {
    if (isNhentaiMode) {
      return await _requestNhentaiRanklistPage(
          ranklistType: ranklistType,
          pageNo: pageNo,
          searchQuery: searchQuery) as T;
    }

    int tl;

    switch (ranklistType) {
      case RanklistType.day:
        tl = 15;
        break;
      case RanklistType.week:
        // EH toplist has no weekly bucket, so keep the closest fallback.
        tl = 13;
        break;
      case RanklistType.month:
        tl = 13;
        break;
      case RanklistType.year:
        tl = 12;
        break;
      case RanklistType.allTime:
        tl = 11;
        break;
    }

    Response response =
        await _getWithErrorHandler('${EHConsts.ERanklist}?tl=$tl&p=$pageNo');
    return _parseResponse(response, parser);
  }

  Future<T> requestSubmitRating<T>(int gid, String token, int apiuid,
      String apikey, int rating, HtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "rategallery",
        'rating': rating,
        'token': token,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestPopupPage<T>(
      int gid, String token, String act, HtmlParser<T> parser) async {
    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _getWithErrorHandler(
      EHConsts.EPopup,
      queryParameters: {
        'gid': gid,
        't': token,
        'act': act,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestFavoritePage<T>(HtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(EHConsts.EFavorite);

    return _parseResponse(response, parser);
  }

  Future<T> requestChangeFavoriteSortOrder<T>(FavoriteSortOrder sortOrder,
      {HtmlParser<T>? parser}) async {
    Response response = await _getWithErrorHandler(
      EHConsts.EFavorite,
      queryParameters: {
        'inline_set':
            sortOrder == FavoriteSortOrder.publishedTime ? 'fs_p' : 'fs_f',
      },
    );

    return _parseResponse(response, parser);
  }

  /// favcat: the favorite tag index
  Future<T> requestAddFavorite<T>(
      int gid, String token, int favcat, String note,
      {HtmlParser<T>? parser}) async {
    if (isNhentaiMode) {
      Response response = await _postWithErrorHandler(
          '$_nhentaiApiBase/galleries/$gid/favorite');
      return _parseResponse(response, parser);
    }

    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _postWithErrorHandler(
      EHConsts.EPopup,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {
        'gid': gid,
        't': token,
        'act': 'addfav',
      },
      data: {
        'favcat': favcat,
        'favnote': note,
        'apply': 'Add to Favorites',
        'update': 1,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestRemoveFavorite<T>(int gid, String token,
      {HtmlParser<T>? parser}) async {
    if (isNhentaiMode) {
      Response response = await _deleteWithErrorHandler(
        '$_nhentaiApiBase/galleries/$gid/favorite',
      );
      return _parseResponse(response, parser);
    }

    /// eg: ?gid=2165080&t=725f6a7a58&act=addfav
    Response response = await _postWithErrorHandler(
      EHConsts.EPopup,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      queryParameters: {
        'gid': gid,
        't': token,
        'act': 'addfav',
      },
      data: {
        'favcat': 'favdel',
        'favnote': '',
        'apply': 'Apply Changes',
        'update': 1,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestImagePage<T>(
    String href, {
    String? reloadKey,
    CancelToken? cancelToken,
    bool useCacheIfAvailable = true,
    required HtmlParser<T> parser,
  }) async {
    if (isNhentaiMode && _isNhentaiImageUrl(href)) {
      return GalleryImage(url: _toAbsoluteNhentaiImageUrl(href)) as T;
    }

    Response response = await _getWithErrorHandler(
      href,
      queryParameters: {
        if (reloadKey != null) 'nl': reloadKey,
      },
      cancelToken: cancelToken,
      options: useCacheIfAvailable
          ? CacheOptions.cacheOptionsIgnoreParams.toOptions()
          : CacheOptions.noCacheOptionsIgnoreParams.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestTorrentPage<T>(
      int gid, String token, HtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(
      EHConsts.ETorrent,
      queryParameters: {
        'gid': gid,
        't': token,
      },
      options: CacheOptions.cacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestSettingPage<T>(HtmlParser<T> parser) async {
    Response response = await _getWithErrorHandler(EHConsts.EUconfig);
    return _parseResponse(response, parser);
  }

  Future<T> createProfile<T>({HtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EUconfig,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'profile_action': 'create',
        'profile_name': 'NHentai',
        'profile_set': '616',
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestMyTagsPage<T>(
      {int tagSetNo = 1, required HtmlParser<T> parser}) async {
    Response response = await _getWithErrorHandler(
      EHConsts.EMyTags,
      queryParameters: {'tagset': tagSetNo},
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestStatPage<T>(
      {required int gid,
      required String token,
      required HtmlParser<T> parser}) async {
    Response response = await _getWithErrorHandler(
      '${EHConsts.EStat}?gid=$gid&t=$token',
      options: CacheOptions.cacheOptions.toOptions(),
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestAddWatchedTag<T>({
    required String tag,
    String? tagColor,
    required int tagWeight,
    required bool watch,
    required bool hidden,
    int tagSetNo = 1,
    HtmlParser<T>? parser,
  }) async {
    Map<String, dynamic> data = {
      'usertag_action': "add",
      'tagname_new': tag,
      'tagcolor_new': tagColor ?? "",
      'usertag_target': 0,
      'tagweight_new': tagWeight,
    };

    if (hidden) {
      data['taghide_new'] = 'on';
    }
    if (watch) {
      data['tagwatch_new'] = 'on';
    }

    Response response;
    try {
      response = await _postWithErrorHandler(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        queryParameters: {'tagset': tagSetNo},
        data: data,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 302) {
        response = e.response!;
      } else {
        rethrow;
      }
    }

    return _parseResponse(response, parser);
  }

  Future<T> requestDeleteWatchedTag<T>(
      {required int watchedTagId,
      int tagSetNo = 1,
      HtmlParser<T>? parser}) async {
    Response response;
    try {
      response = await _postWithErrorHandler(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        queryParameters: {'tagset': tagSetNo},
        data: {
          'usertag_action': 'mass',
          'tagname_new': '',
          'tagcolor_new': '',
          'usertag_target': 0,
          'tagweight_new': 10,
          'modify_usertags[]': watchedTagId,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }
      response = e.response!;
    }

    return _parseResponse(response, parser);
  }

  Future<T> requestUpdateTagSet<T>({
    required int tagSetNo,
    required bool enable,
    required String? color,
    HtmlParser<T>? parser,
  }) async {
    Response response;
    try {
      response = await _postWithErrorHandler(
        EHConsts.EMyTags,
        options: Options(contentType: Headers.formUrlEncodedContentType),
        queryParameters: {'tagset': tagSetNo},
        data: {
          'tagset_action': 'update',
          'tagset_name': '',
          if (enable) 'tagset_enable': 'on',
          'tagset_color': color ?? '',
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }
      response = e.response!;
    }

    return _parseResponse(response, parser);
  }

  Future<T> requestUpdateWatchedTag<T>({
    required int apiuid,
    required String apikey,
    required int tagId,
    required String? tagColor,
    required int tagWeight,
    required bool watch,
    required bool hidden,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHApi,
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'method': "setusertag",
        'apiuid': apiuid,
        'apikey': apikey,
        'tagcolor': tagColor ?? "",
        'taghide': hidden ? 1 : 0,
        'tagwatch': watch ? 1 : 0,
        'tagid': tagId,
        'tagweight': tagWeight.toString(),
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> download<T>({
    required String url,
    required String path,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    bool appendMode = false,
    bool preserveHeaderCase = true,
    int? receiveTimeout,
    String? range,
    bool deleteOnError = true,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _dio.download(
      url,
      path,
      onReceiveProgress: onReceiveProgress,
      shouldAppendFile: appendMode,
      cancelToken: cancelToken,
      deleteOnError: deleteOnError,
      options: Options(
        preserveHeaderCase: preserveHeaderCase,
        headers: range == null ? null : {'Range': range},
        receiveTimeout: Duration(milliseconds: receiveTimeout ?? 0),
      ),
    );

    if (parser == null) {
      return response as T;
    }
    return parser(response.headers, response.data);
  }

  Future<T> voteTag<T>(int gid, String token, int apiuid, String apikey,
      String tag, bool isVotingUp,
      {HtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EApi,
      data: {
        'apikey': apikey,
        'apiuid': apiuid,
        'gid': gid,
        'method': "taggallery",
        'token': token,
        'vote': isVotingUp ? 1 : -1,
        'tags': tag,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestTagSuggestion<T>(
      String keyword, HtmlParser<T> parser) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EApi,
      data: {
        'method': "tagsuggest",
        'text': keyword,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<List<EHRawTag>> requestNhentaiTagSuggestions({
    required String type,
    required String query,
    int limit = 15,
  }) async {
    Response response = await _postWithErrorHandler(
      '$_nhentaiApiBase/tags/search',
      options: Options(contentType: Headers.jsonContentType),
      data: {
        'type': type,
        if (query.trim().isNotEmpty) 'query': query.trim(),
        'limit': limit,
      },
    );

    List<dynamic> list =
        response.data is List ? response.data as List<dynamic> : const [];

    return list
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .map((raw) => EHRawTag(
              namespace: (raw['type'] ?? '').toString(),
              key: (raw['name'] ?? '').toString(),
            ))
        .where((tag) => tag.namespace.isNotEmpty && tag.key.isNotEmpty)
        .toList();
  }

  Future<T> requestSendComment<T>({
    required String galleryUrl,
    required String content,
    required HtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'commenttext_new': content,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestUpdateComment<T>({
    required String galleryUrl,
    required String content,
    required int commentId,
    required HtmlParser<T> parser,
  }) async {
    Response response = await _postWithErrorHandler(
      galleryUrl,
      options: Options(contentType: Headers.formUrlEncodedContentType),
      data: {
        'edit_comment': commentId,
        'commenttext_edit': content,
      },
    );
    return _parseResponse(response, parser);
  }

  Future<T> requestLookup<T>({
    required String imagePath,
    required String imageName,
    required HtmlParser<T> parser,
  }) async {
    try {
      await _postWithErrorHandler(
        EHConsts.ELookup,
        data: FormData.fromMap({
          'sfile': MultipartFile.fromFileSync(
            imagePath,
            filename: imageName,
            contentType: MediaType.parse('application/octet-stream'),
          ),
          'f_sfile': "File Search",
          'fs_similar': 'on',
          'fs_exp': 'on',
        }),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 302) {
        rethrow;
      }

      return _parseResponse(e.response!, parser);
    }

    throw EHSiteException(
        message: 'Look up response error',
        type: EHSiteExceptionType.internalError);
  }

  Future<T> requestUnlockArchive<T>({
    required String url,
    required bool isOriginal,
    CancelToken? cancelToken,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      url,
      data: FormData.fromMap({
        'dltype': isOriginal ? 'org' : 'res',
        'dlcheck': isOriginal
            ? 'Download Original Archive'
            : 'Download Resample Archive',
      }),
      cancelToken: cancelToken,
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestCancelArchive<T>(
      {required String url,
      CancelToken? cancelToken,
      HtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      url,
      cancelToken: cancelToken,
      data: FormData.fromMap({'invalidate_sessions': 1}),
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestHHDownload<T>({
    required String url,
    required String resolution,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      url,
      data: FormData.fromMap({'hathdl_xres': resolution}),
    );

    return _parseResponse(response, parser);
  }

  Future<T> requestExchangePage<T>({HtmlParser<T>? parser}) async {
    Response response = await _getWithErrorHandler(EHConsts.EExchange);

    return _parseResponse(response, parser);
  }

  Future<T> requestResetImageLimit<T>({HtmlParser<T>? parser}) async {
    Response response = await _postWithErrorHandler(
      EHConsts.EHome,
      data: FormData.fromMap({
        'reset_imagelimit': 'Reset Limit',
      }),
    );

    return _parseResponse(response, parser);
  }

  Future<T> get<T>({
    required String url,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _getWithErrorHandler(
      url,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
      options: options,
    );

    return _parseResponse(response, parser);
  }

  Future<T> post<T>({
    required String url,
    data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    HtmlParser<T>? parser,
  }) async {
    Response response = await _postWithErrorHandler(
      url,
      data: data,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
      options: options,
    );

    return _parseResponse(response, parser);
  }

  Future<Response> head<T>(
      {required String url, CancelToken? cancelToken, Options? options}) {
    return _dio.head(
      url,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<GalleryPageInfo> _requestNhentaiGalleryPage({
    String? url,
    String? prevGid,
    String? nextGid,
    SearchConfig? searchConfig,
  }) async {
    int pageNo = _resolveNhentaiPageNo(prevGid: prevGid, nextGid: nextGid);
    bool isPopularRequest = (url?.contains('/popular') ?? false) ||
        searchConfig?.searchType == SearchType.popular;

    String query = _buildNhentaiQuery(
      searchConfig,
      defaultLanguage: preferenceSetting.nhentaiSearchLanguage.value,
    );

    if (searchConfig?.searchType == SearchType.favorite) {
      Response response = await _getWithErrorHandler(
        '$_nhentaiApiBase/favorites',
        queryParameters: {
          'page': pageNo,
          if (query.trim().isNotEmpty) 'q': _ensureNhentaiSearchQuery(query),
        },
      );
      return _nhentaiPageMap2GalleryPageInfo(
        response.data,
        pageNo,
        markAsFavorited: true,
      );
    }

    if (searchConfig?.searchType == SearchType.watched ||
        searchConfig?.searchType == SearchType.history) {
      return GalleryPageInfo(gallerys: []);
    }

    if (isPopularRequest && query.trim().isEmpty) {
      if (pageNo > 1) {
        return GalleryPageInfo(gallerys: [], prevGid: '1', nextGid: null);
      }

      Response response =
          await _getWithErrorHandler('$_nhentaiApiBase/galleries/popular');
      List<dynamic> list =
          response.data is List ? (response.data as List<dynamic>) : const [];
      List<Gallery> gallerys = await _nhentaiSummaryList2Gallerys(list);

      return GalleryPageInfo(
        gallerys: gallerys,
        prevGid: null,
        nextGid: null,
      );
    }

    if (query.trim().isNotEmpty || isPopularRequest) {
      String sortValue = _resolveNhentaiSortValue(
        isPopularRequest: isPopularRequest,
        sortOrder: searchConfig?.nhentaiSortOrder,
      );
      Response response = await _getWithErrorHandler(
        '$_nhentaiApiBase/search',
        queryParameters: {
          'query': _ensureNhentaiSearchQuery(query),
          'sort': sortValue,
          'page': pageNo,
        },
      );
      return _nhentaiPageMap2GalleryPageInfo(response.data, pageNo);
    }

    Response response = await _getWithErrorHandler(
      '$_nhentaiApiBase/galleries',
      queryParameters: {
        'page': pageNo,
      },
    );
    return _nhentaiPageMap2GalleryPageInfo(response.data, pageNo);
  }

  Future<List<dynamic>> _requestNhentaiRanklistPage(
      {required RanklistType ranklistType,
      required int pageNo,
      String? searchQuery}) async {
    String query = _buildNhentaiQuery(
      null,
      defaultLanguage: preferenceSetting.nhentaiSearchLanguage.value,
    );

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      String trimmedSearch = searchQuery.trim();
      query = query.isEmpty ? trimmedSearch : '$trimmedSearch $query';
    }

    Response response = await _getWithErrorHandler(
      '$_nhentaiApiBase/search',
      queryParameters: {
        'query': _ensureNhentaiSearchQuery(query),
        'sort': _nhentaiSortByRanklistType(ranklistType),
        'page': pageNo + 1,
      },
    );

    Map<String, dynamic> map = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : {};
    List<dynamic> result =
        map['result'] is List ? (map['result'] as List<dynamic>) : [];
    List<Gallery> gallerys = await _nhentaiSummaryList2Gallerys(result);

    int pageCount = _asInt(map['num_pages']) ?? 0;
    int? prevPageIndex = pageNo > 0 ? pageNo - 1 : null;
    int? nextPageIndex =
        pageCount == 0 || pageNo + 1 >= pageCount ? null : pageNo + 1;

    return [gallerys, pageCount, prevPageIndex, nextPageIndex];
  }

  Future<Map<String, dynamic>> _requestNhentaiGalleryDetailMap(int gid) async {
    Response response = await _getWithErrorHandler(
      '$_nhentaiApiBase/galleries/$gid',
      queryParameters: {'include': 'comments'},
    );

    if (response.data is! Map) {
      throw EHSiteException(
        type: EHSiteExceptionType.internalError,
        message: 'Invalid gallery detail response',
        shouldPauseAllDownloadTasks: false,
      );
    }

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<GalleryComment>> _requestNhentaiComments(int gid) async {
    Response response =
        await _getWithErrorHandler('$_nhentaiApiBase/galleries/$gid/comments');
    List<dynamic> list =
        response.data is List ? (response.data as List<dynamic>) : const [];
    return _nhentaiRawComments2Comments(list);
  }

  int _resolveNhentaiPageNo({String? prevGid, String? nextGid}) {
    int pageNo = int.tryParse(nextGid ?? prevGid ?? '1') ?? 1;
    return math.max(pageNo, 1);
  }

  int? _extractNhentaiGid(String galleryUrl) {
    Match? match = RegExp(r'/g/(\d+)/?').firstMatch(galleryUrl);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1)!);
  }

  bool _isNhentaiImageUrl(String href) {
    return href.contains('i.nhentai.net/galleries/') ||
        href.contains('t.nhentai.net/galleries/') ||
        href.contains('nhentai.net/galleries/');
  }

  String _ensureNhentaiSearchQuery(String query) {
    String normalized = query.trim();
    return normalized.isEmpty ? ' ' : normalized;
  }

  String? _nhentaiAuthorizationValue() {
    String? apiKey = userSetting.nhApiKey.value?.trim();
    if (!isEmptyOrNull(apiKey)) {
      return 'Key $apiKey';
    }

    return null;
  }

  bool _isNhentaiApiUrl(String url) {
    return url.startsWith(_nhentaiApiBase);
  }

  Options? _attachNhentaiAuthorization(String url, Options? options) {
    if (!_isNhentaiApiUrl(url)) {
      return options;
    }

    Map<String, dynamic> headers =
        Map<String, dynamic>.from(options?.headers ?? const {});
    headers.putIfAbsent('User-Agent', () => _nhentaiUserAgent);

    String? authorization = _nhentaiAuthorizationValue();
    if (authorization != null) {
      headers.putIfAbsent('Authorization', () => authorization);
    }

    if (options == null) {
      return Options(headers: headers);
    }

    return options.copyWith(headers: headers);
  }

  String _buildNhentaiQuery(SearchConfig? searchConfig,
      {String? defaultLanguage}) {
    SearchConfig? normalizedSearchConfig = searchConfig?.copyWith();
    normalizedSearchConfig?.normalizeForNhentai();

    List<String> terms = [];

    if (!isEmptyOrNull(normalizedSearchConfig?.keyword)) {
      terms.add(normalizedSearchConfig!.keyword!.trim());
    }

    normalizedSearchConfig?.tags?.forEach((tag) {
      String key = tag.key.trim();
      if (key.isEmpty) {
        return;
      }

      if (tag.namespace.trim().isEmpty || tag.namespace == 'temp') {
        terms.add(key);
        return;
      }

      if (key.contains(' ')) {
        key = '"$key"';
      }
      terms.add('${tag.namespace}:$key');
    });

    if (!isEmptyOrNull(normalizedSearchConfig?.language)) {
      terms.add('language:${normalizedSearchConfig!.language!.trim()}');
    }

    terms.addAll(
        normalizedSearchConfig?.computeNhentaiExcludedCategoryTerms() ??
            const []);

    String query =
        terms.where((term) => term.trim().isNotEmpty).join(' ').trim();
    bool hasLanguageClause =
        RegExp(r'(^|\s)language:', caseSensitive: false).hasMatch(query);
    String? normalizedDefaultLanguage = defaultLanguage?.trim();
    if (!isEmptyOrNull(normalizedDefaultLanguage) && !hasLanguageClause) {
      query = query.isEmpty
          ? 'language:$normalizedDefaultLanguage'
          : 'language:$normalizedDefaultLanguage $query';
    }

    return query.trim();
  }

  String _nhentaiSortByRanklistType(RanklistType ranklistType) {
    switch (ranklistType) {
      case RanklistType.day:
        return 'popular-today';
      case RanklistType.week:
        return 'popular-week';
      case RanklistType.month:
        return 'popular-month';
      case RanklistType.year:
        // nhentai does not expose a yearly ranking; keep legacy behavior
        // if a stale state still points at this option.
        return 'popular-month';
      case RanklistType.allTime:
        return 'popular';
    }
  }

  String _resolveNhentaiSortValue({
    required bool isPopularRequest,
    required NhentaiSortOrder? sortOrder,
  }) {
    if (sortOrder != null) {
      switch (sortOrder) {
        case NhentaiSortOrder.date:
          return 'date';
        case NhentaiSortOrder.popularToday:
          return 'popular-today';
        case NhentaiSortOrder.popularWeek:
          return 'popular-week';
        case NhentaiSortOrder.popularMonth:
          return 'popular-month';
        case NhentaiSortOrder.popular:
          return 'popular';
      }
    }
    return isPopularRequest ? 'popular' : 'date';
  }

  Future<GalleryPageInfo> _nhentaiPageMap2GalleryPageInfo(
      dynamic data, int pageNo,
      {bool markAsFavorited = false}) async {
    Map<String, dynamic> map =
        data is Map ? Map<String, dynamic>.from(data) : {};
    List<dynamic> result =
        map['result'] is List ? (map['result'] as List<dynamic>) : const [];
    List<Gallery> gallerys = await _nhentaiSummaryList2Gallerys(
      result,
      markAsFavorited: markAsFavorited,
    );

    int pageCount = _asInt(map['num_pages']) ?? 0;
    GalleryCount? totalCount;
    if (_asInt(map['total']) != null) {
      totalCount = GalleryCount(
          type: GalleryCountType.accurate,
          count: _asInt(map['total'])!.toString());
    }

    return GalleryPageInfo(
      gallerys: gallerys,
      totalCount: totalCount,
      prevGid: pageNo > 1 ? '${pageNo - 1}' : null,
      nextGid: pageCount == 0 || pageNo >= pageCount ? null : '${pageNo + 1}',
    );
  }

  Future<List<Gallery>> _nhentaiSummaryList2Gallerys(List<dynamic> list,
      {bool markAsFavorited = false}) async {
    await _ensureNhTagZhMapLoaded();

    Set<int> tagIds = {};
    for (dynamic item in list) {
      if (item is! Map) {
        continue;
      }
      List<dynamic> ids = item['tag_ids'] is List
          ? (item['tag_ids'] as List<dynamic>)
          : const [];
      tagIds.addAll(ids.map(_asInt).whereType<int>());
    }

    Map<int, Map<String, dynamic>> tagsById =
        await _nhentaiResolveTagsByIds(tagIds.toList());

    return list.whereType<Map>().map((item) {
      Map<String, dynamic> map = Map<String, dynamic>.from(item);
      LinkedHashMap<String, List<GalleryTag>> tags =
          _nhentaiTagIds2TagMap(map['tag_ids'] as List? ?? [], tagsById);
      String publishTime = _unixSeconds2UtcString(map['upload_date']);
      if (publishTime.isEmpty) {
        publishTime = DateTime.now().toUtc().toString();
      }

      return Gallery(
        galleryUrl: GalleryUrl(
          isEH: true,
          gid: _asInt(map['id']) ?? -1,
          token: GalleryUrl.fakeNhentaiToken(_asInt(map['id']) ?? -1),
          isNhentai: true,
        ),
        title: (map['english_title'] ?? map['japanese_title'] ?? '').toString(),
        category: _nhentaiExtractCategory(tags),
        cover: GalleryImage(
          url: _toAbsoluteNhentaiThumbUrl(map['thumbnail']),
          width: _asDouble(map['thumbnail_width']),
          height: _asDouble(map['thumbnail_height']),
        ),
        pageCount: _asInt(map['num_pages']),
        rating: 0,
        hasRated: false,
        favoriteTagIndex: markAsFavorited ? 1 : null,
        favoriteTagName: markAsFavorited ? 'favorite'.tr : null,
        language: _nhentaiExtractLanguage(tags),
        uploader: _nhentaiExtractUploader(tags: tags),
        publishTime: publishTime,
        isExpunged: false,
        tags: tags,
      );
    }).toList();
  }

  Future<Map<int, Map<String, dynamic>>> _nhentaiResolveTagsByIds(
      List<int> ids) async {
    List<int> toFetch =
        ids.where((id) => !_nhTagCache.containsKey(id)).toList();

    for (int i = 0; i < toFetch.length; i += 100) {
      List<int> chunk = toFetch.sublist(i, math.min(i + 100, toFetch.length));
      if (chunk.isEmpty) {
        continue;
      }

      try {
        Response response = await _getWithErrorHandler(
          '$_nhentaiApiBase/tags/ids',
          queryParameters: {
            'ids': chunk.join(','),
          },
        );

        if (response.data is! List) {
          continue;
        }

        for (dynamic rawTag in response.data as List<dynamic>) {
          if (rawTag is! Map) {
            continue;
          }

          Map<String, dynamic> tag = Map<String, dynamic>.from(rawTag);
          int? tagId = _asInt(tag['id']);
          if (tagId != null) {
            _nhTagCache[tagId] = tag;
          }
        }
      } catch (e, s) {
        log.error('Fetch nhentai tags by ids failed', e, s);
      }
    }

    Map<int, Map<String, dynamic>> result = {};
    for (int id in ids) {
      if (_nhTagCache[id] != null) {
        result[id] = _nhTagCache[id]!;
      }
    }
    return result;
  }

  LinkedHashMap<String, List<GalleryTag>> _nhentaiTagIds2TagMap(
      List<dynamic> tagIds, Map<int, Map<String, dynamic>> tagsById) {
    LinkedHashMap<String, List<GalleryTag>> map = LinkedHashMap();

    for (dynamic rawId in tagIds) {
      int? id = _asInt(rawId);
      Map<String, dynamic>? tag = id == null ? null : tagsById[id];
      if (tag == null) {
        continue;
      }

      String namespace = _nhentaiTagType2Namespace(tag['type']);
      String key = (tag['name'] ?? '').toString();
      if (key.isEmpty) {
        continue;
      }
      String? translatedName = id == null ? null : _nhTagZhMap[id];

      map.putIfAbsent(namespace, () => []).add(GalleryTag(
          tagData: TagData(
              namespace: namespace, key: key, tagName: translatedName)));
    }

    return map;
  }

  LinkedHashMap<String, List<GalleryTag>> _nhentaiTagList2TagMap(
      List<dynamic> tags) {
    LinkedHashMap<String, List<GalleryTag>> map = LinkedHashMap();

    for (dynamic raw in tags) {
      if (raw is! Map) {
        continue;
      }

      Map<String, dynamic> tag = Map<String, dynamic>.from(raw);
      String namespace = _nhentaiTagType2Namespace(tag['type']);
      String key = (tag['name'] ?? '').toString();
      if (key.isEmpty) {
        continue;
      }
      String? translatedName = _nhTagZhMap[_asInt(tag['id'])];

      map.putIfAbsent(namespace, () => []).add(GalleryTag(
          tagData: TagData(
              namespace: namespace, key: key, tagName: translatedName)));
    }

    return map;
  }

  String _nhentaiTagType2Namespace(dynamic rawType) {
    String type = (rawType ?? '').toString().trim().toLowerCase();
    if (type.isEmpty) {
      return 'tag';
    }
    if (type == 'category') {
      return 'rows';
    }
    return type;
  }

  String _nhentaiExtractCategory(LinkedHashMap<String, List<GalleryTag>> tags) {
    List<GalleryTag>? categories = tags['rows'];
    if (categories == null || categories.isEmpty) {
      return 'Unknown';
    }
    String key = categories.first.tagData.key.toLowerCase();
    switch (key) {
      case 'doujinshi':
        return 'Doujinshi';
      case 'manga':
        return 'Manga';
      case 'artist cg':
        return 'Artist CG';
      case 'game cg':
        return 'Game CG';
      case 'western':
        return 'Western';
      case 'non-h':
        return 'Non-H';
      case 'image set':
      case 'imageset':
        return 'Image Set';
      case 'cosplay':
        return 'Cosplay';
      case 'asian porn':
        return 'Asian Porn';
      case 'misc':
        return 'Misc';
      default:
        return categories.first.tagData.key;
    }
  }

  String _nhentaiExtractLanguage(LinkedHashMap<String, List<GalleryTag>> tags) {
    List<GalleryTag> languages = tags['language'] ?? const [];
    for (GalleryTag tag in languages) {
      if (tag.tagData.key != 'translated') {
        return tag.tagData.key;
      }
    }
    return 'japanese';
  }

  String? _nhentaiExtractUploader({
    required LinkedHashMap<String, List<GalleryTag>> tags,
    String? scanlator,
  }) {
    String? normalizedScanlator = scanlator?.trim();
    if (normalizedScanlator != null && normalizedScanlator.isNotEmpty) {
      return normalizedScanlator;
    }

    List<GalleryTag> artists = tags['artist'] ?? const [];
    for (GalleryTag artist in artists) {
      String key = artist.tagData.key.trim();
      if (key.isNotEmpty) {
        return key;
      }
    }

    List<GalleryTag> groups = tags['group'] ?? const [];
    for (GalleryTag group in groups) {
      String key = group.tagData.key.trim();
      if (key.isNotEmpty) {
        return key;
      }
    }

    return null;
  }

  Future<GalleryDetail> _nhentaiDetailMap2GalleryDetail(
      Map<String, dynamic> map, int thumbnailsPageIndex) async {
    await _ensureNhTagZhMapLoaded();

    LinkedHashMap<String, List<GalleryTag>> tags =
        _nhentaiTagList2TagMap(map['tags'] as List? ?? []);
    List<dynamic> pages =
        map['pages'] is List ? (map['pages'] as List<dynamic>) : const [];

    Map<String, dynamic> titleMap = map['title'] is Map
        ? Map<String, dynamic>.from(map['title'] as Map)
        : {};

    String rawTitle = (titleMap['english'] ??
            titleMap['pretty'] ??
            titleMap['japanese'] ??
            '')
        .toString();
    String? japaneseTitle = (titleMap['japanese'] ?? '').toString().trim();
    if (japaneseTitle.isEmpty) {
      japaneseTitle = null;
    }

    String? scanlator = (map['scanlator'] ?? '').toString().trim();
    if (scanlator.isEmpty) {
      scanlator = null;
    }

    int gid = _asInt(map['id']) ?? -1;
    bool isFavorited = map['is_favorited'] == true;

    return GalleryDetail(
      galleryUrl: GalleryUrl(
          isEH: true,
          gid: gid,
          token: GalleryUrl.fakeNhentaiToken(gid),
          isNhentai: true),
      rawTitle: rawTitle,
      japaneseTitle: japaneseTitle,
      category: _nhentaiExtractCategory(tags),
      cover: GalleryImage(
        url: _toAbsoluteNhentaiThumbUrl((map['cover'] as Map?)?['path']),
        width: _asDouble((map['cover'] as Map?)?['width']),
        height: _asDouble((map['cover'] as Map?)?['height']),
      ),
      pageCount: _asInt(map['num_pages']) ?? pages.length,
      rating: 0,
      realRating: 0,
      hasRated: false,
      ratingCount: 0,
      favoriteTagIndex: isFavorited ? 1 : null,
      favoriteTagName: isFavorited ? 'favorite'.tr : null,
      favoriteCount: _asInt(map['num_favorites']) ?? 0,
      language: _nhentaiExtractLanguage(tags),
      uploader: _nhentaiExtractUploader(tags: tags, scanlator: scanlator),
      publishTime: _unixSeconds2UtcString(map['upload_date']),
      isExpunged: false,
      tags: tags,
      size: '-',
      torrentCount: '0',
      torrentPageUrl: '',
      archivePageUrl: '',
      parentGalleryUrl: null,
      childrenGallerys: null,
      comments:
          _nhentaiRawComments2Comments(map['comments'] as List? ?? const []),
      thumbnails: _nhentaiBuildThumbnails(pages, thumbnailsPageIndex),
      thumbnailsPageCount: _nhentaiThumbnailsPageCount(pages.length),
    );
  }

  Future<void> _ensureNhTagZhMapLoaded() async {
    if (_nhTagZhMap.isNotEmpty) {
      return;
    }

    if (_nhTagZhLoadingTask != null) {
      await _nhTagZhLoadingTask;
      return;
    }

    _nhTagZhLoadingTask = _loadNhTagZhMap();
    try {
      await _nhTagZhLoadingTask;
    } finally {
      _nhTagZhLoadingTask = null;
    }
  }

  Future<void> _loadNhTagZhMap() async {
    try {
      String raw = await rootBundle.loadString(_nhentaiTagZhAssetPath);
      Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;

      _nhTagZhMap.clear();
      decoded.forEach((rawId, dynamic value) {
        int? id = int.tryParse(rawId);
        String text = value?.toString().trim() ?? '';
        if (id != null && text.isNotEmpty) {
          _nhTagZhMap[id] = text;
        }
      });

      log.info('Loaded nhentai zh tag dictionary: ${_nhTagZhMap.length}');
    } catch (e, s) {
      log.error('Load nhentai zh tag dictionary failed', e, s);
      _nhTagZhMap.clear();
    }
  }

  List<GalleryThumbnail> _nhentaiBuildThumbnails(
      List<dynamic> pages, int pageIndex) {
    if (pages.isEmpty) {
      return const [];
    }

    int start = pageIndex * _nhentaiThumbsPerPage;
    if (start >= pages.length) {
      return const [];
    }

    int end = math.min(start + _nhentaiThumbsPerPage, pages.length);

    return pages.sublist(start, end).whereType<Map>().map((raw) {
      Map<String, dynamic> page = Map<String, dynamic>.from(raw);

      return GalleryThumbnail(
        href: _toAbsoluteNhentaiImageUrl(page['path']),
        isLarge: true,
        thumbUrl: _toAbsoluteNhentaiThumbUrl(page['thumbnail'] ?? page['path']),
        thumbWidth: _asDouble(page['thumbnail_width']),
        thumbHeight: _asDouble(page['thumbnail_height']),
      );
    }).toList();
  }

  DetailPageInfo _nhentaiBuildDetailPageInfo(
      Map<String, dynamic> map, int pageIndex) {
    List<dynamic> pages =
        map['pages'] is List ? (map['pages'] as List<dynamic>) : const [];
    int imageCount = pages.length;
    int pageCount = _nhentaiThumbnailsPageCount(imageCount);

    if (imageCount == 0) {
      return const DetailPageInfo(
        imageNoFrom: 0,
        imageNoTo: 0,
        imageCount: 0,
        currentPageNo: 1,
        pageCount: 0,
        thumbnails: [],
      );
    }

    int safePageIndex = math.max(0, math.min(pageIndex, pageCount - 1));
    int imageNoFrom = safePageIndex * _nhentaiThumbsPerPage;
    int imageNoTo =
        math.min(imageNoFrom + _nhentaiThumbsPerPage, imageCount) - 1;

    return DetailPageInfo(
      imageNoFrom: imageNoFrom,
      imageNoTo: imageNoTo,
      imageCount: imageCount,
      currentPageNo: safePageIndex + 1,
      pageCount: pageCount,
      thumbnails: _nhentaiBuildThumbnails(pages, safePageIndex),
    );
  }

  int _nhentaiThumbnailsPageCount(int imageCount) {
    if (imageCount <= 0) {
      return 0;
    }
    return (imageCount + _nhentaiThumbsPerPage - 1) ~/ _nhentaiThumbsPerPage;
  }

  List<GalleryComment> _nhentaiRawComments2Comments(List<dynamic> rawComments) {
    return rawComments.whereType<Map>().map((raw) {
      Map<String, dynamic> comment = Map<String, dynamic>.from(raw);
      Map<String, dynamic> poster = comment['poster'] is Map
          ? Map<String, dynamic>.from(comment['poster'] as Map)
          : {};

      String body = (comment['body'] ?? '').toString();
      DocumentFragment fragment =
          html_parser.parseFragment(body.replaceAll('\n', '<br/>'));
      Element content = Element.tag('span')..nodes.addAll(fragment.nodes);

      return GalleryComment(
        id: _asInt(comment['id']) ?? 0,
        username: poster['username']?.toString(),
        userId: _asInt(poster['id']),
        score: '0',
        scoreDetails: const [],
        content: content,
        time: _unixSeconds2UtcString(comment['post_date']),
        lastEditTime: null,
        fromMe: false,
        votedUp: false,
        votedDown: false,
      );
    }).toList();
  }

  String _toAbsoluteNhentaiImageUrl(dynamic raw) {
    String path = _normalizeNhentaiPath(raw);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${_nhentaiImageServers.first}/$path';
  }

  String _toAbsoluteNhentaiThumbUrl(dynamic raw) {
    String path = _normalizeNhentaiPath(raw);
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${_nhentaiThumbServers.first}/$path';
  }

  String _normalizeNhentaiPath(dynamic raw) {
    String path = (raw ?? '').toString().trim();
    path = path.replaceFirst(RegExp(r'^/+'), '');

    while (path.contains('.webp.webp')) {
      path = path.replaceAll('.webp.webp', '.webp');
    }
    while (path.contains('.jpg.jpg')) {
      path = path.replaceAll('.jpg.jpg', '.jpg');
    }
    while (path.contains('.jpeg.jpeg')) {
      path = path.replaceAll('.jpeg.jpeg', '.jpeg');
    }
    while (path.contains('.png.png')) {
      path = path.replaceAll('.png.png', '.png');
    }

    return path;
  }

  String _unixSeconds2UtcString(dynamic raw) {
    int? seconds = _asInt(raw);
    if (seconds == null) {
      return '';
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .toString();
  }

  int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  Future<T> _parseResponse<T>(Response response, HtmlParser<T>? parser) async {
    if (parser == null) {
      return response as T;
    }
    return isolateService.run(
        (list) => parser(list[0], list[1]), [response.headers, response.data]);
  }

  Future<Response> _getWithErrorHandler<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    Options? optionsWithAuth = _attachNhentaiAuthorization(url, options);
    int retryCount = 0;

    while (true) {
      Response response;
      try {
        response = await _dio.get(
          url,
          queryParameters: queryParameters,
          options: optionsWithAuth,
          cancelToken: cancelToken,
          onReceiveProgress: onReceiveProgress,
        );
      } on DioException catch (e) {
        if (_shouldRetryNhentai429(
          url: url,
          exception: e,
          retryCount: retryCount,
          cancelToken: cancelToken,
        )) {
          Duration delay = _computeNhentai429RetryDelay(
            e.response?.headers,
            retryCount,
          );
          retryCount++;
          log.warning('NHentai API rate limited, retry in ${delay.inSeconds}s. '
              'url:$url retry:$retryCount');
          await Future<void>.delayed(delay);
          continue;
        }
        throw _convertExceptionIfGalleryDeleted(e);
      }

      try {
        _emitEHExceptionIfFailed(response);
      } on EHSiteException catch (_) {
        removeCacheByUrl(response.requestOptions.uri.toString());
        rethrow;
      }

      return response;
    }
  }

  Future<Response> _postWithErrorHandler<T>(
    String url, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    Response response;
    Options? optionsWithAuth = _attachNhentaiAuthorization(url, options);
    try {
      response = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: optionsWithAuth,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _convertExceptionIfGalleryDeleted(e);
    }

    _emitEHExceptionIfFailed(response);

    return response;
  }

  Future<Response> _deleteWithErrorHandler<T>(
    String url, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    Response response;
    Options? optionsWithAuth = _attachNhentaiAuthorization(url, options);
    try {
      response = await _dio.delete(
        url,
        data: data,
        queryParameters: queryParameters,
        options: optionsWithAuth,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _convertExceptionIfGalleryDeleted(e);
    }

    _emitEHExceptionIfFailed(response);

    return response;
  }

  Exception _convertExceptionIfGalleryDeleted(DioException e) {
    if (e.response?.statusCode == 404 &&
        networkSetting.allHostAndIPs.contains(e.requestOptions.uri.host)) {
      String? errMessage = EHSpiderParser.a404Page2GalleryDeletedHint(
          e.response!.headers, e.response!.data);
      if (!isEmptyOrNull(errMessage)) {
        return EHSiteException(
          type: EHSiteExceptionType.galleryDeleted,
          message: errMessage!,
          shouldPauseAllDownloadTasks: false,
        );
      }
    }
    if (e.response?.statusCode == 403 &&
        networkSetting.allHostAndIPs.contains(e.requestOptions.uri.host)) {
      return EHSiteException(
        type: EHSiteExceptionType.cloudflare,
        message: 'cloudflare403'.tr,
        shouldPauseAllDownloadTasks: false,
      );
    }

    return e;
  }

  bool _shouldRetryNhentai429({
    required String url,
    required DioException exception,
    required int retryCount,
    CancelToken? cancelToken,
  }) {
    return _isNhentaiApiUrl(url) &&
        retryCount < _nhentai429RetryTimes &&
        cancelToken?.isCancelled != true &&
        exception.response?.statusCode == 429;
  }

  Duration _computeNhentai429RetryDelay(Headers? headers, int retryCount) {
    Duration? retryAfter = _parseRetryAfter(headers);
    if (retryAfter != null) {
      return retryAfter;
    }

    int seconds = math.min(8, 1 << retryCount);
    return Duration(seconds: seconds);
  }

  Duration? _parseRetryAfter(Headers? headers) {
    String? raw = headers?.value('retry-after')?.trim();
    if (isEmptyOrNull(raw)) {
      return null;
    }

    int? seconds = int.tryParse(raw!);
    if (seconds != null) {
      return Duration(seconds: math.max(1, math.min(30, seconds)));
    }

    try {
      DateTime retryAt = HttpDate.parse(raw);
      Duration duration = retryAt.difference(DateTime.now().toUtc());
      if (duration.isNegative) {
        return const Duration(seconds: 1);
      }
      return duration > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : duration;
    } on FormatException {
      return null;
    }
  }

  void _emitEHExceptionIfFailed(Response response) {
    if (!networkSetting.allHostAndIPs
        .contains(response.requestOptions.uri.host)) {
      return;
    }

    if (response.data is String) {
      String data = response.data.toString();

      if (data.isEmpty) {
        throw EHSiteException(
            type: EHSiteExceptionType.blankBody,
            message: 'sadPanda'.tr,
            referLink: 'sadPandaReferLink'.tr);
      }

      if (data.startsWith('Your IP address')) {
        throw EHSiteException(
            type: EHSiteExceptionType.banned, message: response.data);
      }
      if (data.startsWith('This IP address')) {
        throw EHSiteException(
            type: EHSiteExceptionType.banned, message: response.data);
      }

      if (data.startsWith('You have exceeded your image')) {
        throw EHSiteException(
            type: EHSiteExceptionType.exceedLimit,
            message: 'exceedImageLimits'.tr);
      }

      if (data.contains('Page load has been aborted due to a fatal error')) {
        throw EHSiteException(
            type: EHSiteExceptionType.ehServerError,
            message: 'ehServerError'.tr,
            shouldPauseAllDownloadTasks: false);
      }
    }
  }
}
