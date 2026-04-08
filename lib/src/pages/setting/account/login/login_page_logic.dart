import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../service/log.dart';
import 'login_page_state.dart';

class LoginPageLogic extends GetxController {
  static const loadingStateId = 'loadingStateId';

  final LoginPageState state = LoginPageState();

  Future<void> handleLogin() async {
    if (state.loginState == LoadingState.loading) {
      return;
    }

    String? apiKey = _normalize(state.apiKey);
    if (apiKey == null) {
      toast('pleaseInputApiKey'.tr, isShort: true);
      return;
    }

    Get.focusScope?.unfocus();
    state.loginState = LoadingState.loading;
    update([loadingStateId]);

    try {
      log.info('Start saving NH API key. length=${apiKey.length}');
      String? displayName = await _fetchDisplayNameByApiKey(apiKey);

      await userSetting.saveNhentaiAuth(
        apiKey: apiKey,
        displayName: displayName,
      );

      log.info('NH API key saved. hasApiKey=${apiKey.isNotEmpty}, '
          'displayName=${displayName ?? userSetting.displayName}');

      state.loginState = LoadingState.success;
      update([loadingStateId]);

      toast('loginSuccess'.tr);
      backRoute(currentRoute: Routes.login);
    } catch (e) {
      log.error('Save NH API key failed', e);
      state.loginState = LoadingState.error;
      update([loadingStateId]);
      toast('loginFail'.tr, isShort: true);
    }
  }

  Future<String?> _fetchDisplayNameByApiKey(String apiKey) async {
    try {
      dio.Response response = await ehRequest.get<dio.Response>(
        url: 'https://nhentai.net/api/v2/user',
        options: dio.Options(
          headers: {
            'Authorization': 'Key $apiKey',
            'User-Agent': 'NHentaiApp/1.0 (JHenTai Fork)',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      log.info('NH user endpoint response: status=${response.statusCode}');
      if (response.statusCode != 200 || response.data is! Map) {
        log.warning('NH user endpoint returns unexpected body type: '
            '${response.data.runtimeType}');
        return null;
      }

      Map map = response.data as Map;
      String username = (map['username'] ?? '').toString().trim();
      if (username.isEmpty) {
        return null;
      }

      return username;
    } on dio.DioException catch (e) {
      log.warning(
        'Fetch NH username by API key failed. '
        'type=${e.type}, code=${e.response?.statusCode}, uri=${e.requestOptions.uri}',
        e,
      );
      dynamic body = e.response?.data;
      if (body != null) {
        log.debug('NH user endpoint error body: ${_limit(body.toString())}');
      }
      return null;
    } catch (e) {
      log.warning('Fetch NH username by API key failed', e);
      return null;
    }
  }

  String? _normalize(String? value) {
    if (value == null) {
      return null;
    }

    String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _limit(String text, {int max = 240}) {
    if (text.length <= max) {
      return text;
    }
    return '${text.substring(0, max)}...';
  }
}
