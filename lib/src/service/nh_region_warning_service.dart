import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/snack_util.dart';

NhRegionWarningService nhRegionWarningService = NhRegionWarningService();

class NhRegionWarningService {
  static const Duration _minimumCheckInterval = Duration(minutes: 5);
  static const Set<String> _japanCloudflarePopCodes = <String>{
    'NRT',
    'HND',
    'KIX',
    'ITM',
    'NGO',
    'FUK',
    'CTS',
    'OKA',
    'SDJ',
    'HIJ',
  };

  bool _checking = false;
  DateTime? _lastCheckTime;
  String? _lastWarningFingerprint;

  Future<void> checkAndWarnIfJapanExitNode({bool force = false}) async {
    if (_checking || Get.context == null) {
      return;
    }

    if (!force &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _minimumCheckInterval) {
      return;
    }

    _checking = true;
    _lastCheckTime = DateTime.now();

    try {
      _NhRegionRisk? risk = await _detectJapanExitRisk();
      if (risk == null) {
        return;
      }

      if (!force && _lastWarningFingerprint == risk.fingerprint) {
        return;
      }

      _lastWarningFingerprint = risk.fingerprint;
      snack('attention'.tr, 'japanIpRiskHint'.tr, isShort: false);
      log.warning('Detected possible Japan exit node for nhentai: ${risk.reason}');
    } catch (e, s) {
      log.error('Check nhentai region warning failed', e, s);
    } finally {
      _checking = false;
    }
  }

  Future<_NhRegionRisk?> _detectJapanExitRisk() async {
    String? proxyHost = _extractHost(ehRequest.currentProxyConfig()?.address);
    if (_looksLikeJapaneseProxy(proxyHost)) {
      return _NhRegionRisk(
        reason: 'proxy:$proxyHost',
        fingerprint: 'proxy:$proxyHost',
      );
    }

    // Only use nhentai's own API metadata here to avoid depending on
    // third-party IP lookup sites that can fail independently.
    dio.Response response = await ehRequest.get<dio.Response>(
      url: 'https://nhentai.net/api/v2/cdn',
    );

    String? cfRay = response.headers.value('cf-ray');
    String? popCode = _extractCloudflarePopCode(cfRay);
    if (popCode != null && _japanCloudflarePopCodes.contains(popCode)) {
      return _NhRegionRisk(
        reason: 'cf-ray:$popCode',
        fingerprint: 'cf-ray:$popCode',
      );
    }

    return null;
  }

  String? _extractHost(String? address) {
    if (address == null || address.trim().isEmpty) {
      return null;
    }

    String normalized = address.trim();
    if (!normalized.contains('://')) {
      normalized = 'scheme://$normalized';
    }

    try {
      Uri uri = Uri.parse(normalized);
      return uri.host.isEmpty ? null : uri.host.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeJapaneseProxy(String? host) {
    if (host == null || host.isEmpty) {
      return false;
    }

    return host.endsWith('.jp') ||
        host.contains('.jp.') ||
        host.contains('-jp.') ||
        host.contains('.jp-') ||
        host == 'jp';
  }

  String? _extractCloudflarePopCode(String? cfRay) {
    if (cfRay == null || cfRay.trim().isEmpty || !cfRay.contains('-')) {
      return null;
    }

    return cfRay.split('-').last.trim().toUpperCase();
  }
}

class _NhRegionRisk {
  final String reason;
  final String fingerprint;

  const _NhRegionRisk({
    required this.reason,
    required this.fingerprint,
  });
}
