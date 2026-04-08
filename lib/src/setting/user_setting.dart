import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/log.dart';

import '../service/jh_service.dart';

UserSetting userSetting = UserSetting();

class UserSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  RxnString userName = RxnString();
  RxnInt ipbMemberId = RxnInt();
  RxnString ipbPassHash = RxnString();
  RxnString avatarImgUrl = RxnString();
  RxnString nickName = RxnString();

  /// nhentai auth model: API Key only.
  RxnString nhApiKey = RxnString();

  /// Kept for backward-compatible config reads. No longer used for auth.
  RxnString nhUserToken = RxnString();

  /// Keep legacy EH login semantics for EH-only code paths.
  bool hasLoggedIn() => hasAnyAuth();

  bool hasLegacyEhAuth() => ipbMemberId.value != null;

  bool hasNhAuth() => _normalizeAuthValue(nhApiKey.value) != null;

  bool hasAnyAuth() => hasLegacyEhAuth() || hasNhAuth();

  String? get displayName {
    String? nick = _normalizeAuthValue(nickName.value);
    if (nick != null) {
      return nick;
    }

    String? user = _normalizeAuthValue(userName.value);
    if (user != null) {
      return user;
    }

    if (hasNhAuth()) {
      return 'NH User';
    }

    return null;
  }

  @override
  ConfigEnum get configEnum => ConfigEnum.userSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    userName = RxnString(map['userName']);
    ipbMemberId = RxnInt(map['ipbMemberId']);
    ipbPassHash = RxnString(map['ipbPassHash']);
    avatarImgUrl = RxnString(map['avatarImgUrl']);
    nickName = RxnString(map['nickName']);


    nhApiKey = RxnString(map['nhApiKey']);
    nhUserToken = RxnString(map['nhUserToken']);
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'userName': userName.value,
      'ipbMemberId': ipbMemberId.value,
      'ipbPassHash': ipbPassHash.value,
      'avatarImgUrl': avatarImgUrl.value,
      'nickName': nickName.value,

      'nhApiKey': nhApiKey.value,
      'nhUserToken': nhUserToken.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> saveUserInfo({
    required String userName,
    required int ipbMemberId,
    required String ipbPassHash,
    String? avatarImgUrl,
    String? nickName,
  }) async {
    log.debug(
        'saveUserInfo: $userName, $ipbMemberId, $ipbPassHash, $avatarImgUrl, $nickName');
    this.userName.value = userName;
    this.ipbPassHash.value = ipbPassHash;
    this.ipbMemberId.value = ipbMemberId;
    this.avatarImgUrl.value = avatarImgUrl;
    this.nickName.value = nickName;
    await saveBeanConfig();
  }

  Future<void> saveNhentaiAuth({
    required String? apiKey,
    String? displayName,
  }) async {
    String? normalizedApiKey = _normalizeAuthValue(apiKey);

    if (normalizedApiKey == null) {
      throw ArgumentError('apiKey is required.');
    }

    nhApiKey.value = normalizedApiKey;
    nhUserToken.value = null;

    String? normalizedDisplayName = _normalizeAuthValue(displayName);
    String? existingUserName = _normalizeAuthValue(this.userName.value);
    if (_isPlaceholderDisplayName(existingUserName)) {
      existingUserName = null;
    }
    String fallbackName =
        normalizedDisplayName ?? existingUserName ?? 'NH User';
    this.userName.value = fallbackName;
    this.nickName.value = fallbackName;

    await saveBeanConfig();
  }

  Future<void> clearNhentaiAuth() async {
    nhApiKey.value = null;
    nhUserToken.value = null;

    if (!hasLegacyEhAuth()) {
      avatarImgUrl.value = null;
      nickName.value = null;
      userName.value = null;
    }

    await saveBeanConfig();
  }

  Future<void> saveUserNameAndAvatarAndNickName({
    required String userName,
    String? avatarImgUrl,
    required String nickName,
  }) async {
    log.debug('saveUserNameAndAvatar:$userName $avatarImgUrl $nickName');
    this.userName.value = userName;
    this.avatarImgUrl.value = avatarImgUrl;
    this.nickName.value = nickName;
    await saveBeanConfig();
  }


  @override
  Future<bool> clearBeanConfig() async {
    bool success = await super.clearBeanConfig();
    userName.value = null;
    ipbMemberId.value = null;
    ipbPassHash.value = null;
    avatarImgUrl.value = null;
    nickName.value = null;

    nhApiKey.value = null;
    nhUserToken.value = null;
    return success;
  }

  String? _normalizeAuthValue(String? value) {
    if (value == null) {
      return null;
    }

    String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _isPlaceholderDisplayName(String? value) {
    if (value == null) {
      return false;
    }

    return value == 'NH User' || value == 'NH 用户';
  }
}
