import 'package:jhentai/src/exception/internal_exception.dart';

class GalleryUrl {
  final bool isEH;
  final bool isNhentai;

  final int gid;

  final String token;

  const GalleryUrl({
    required this.isEH,
    required this.gid,
    required this.token,
    this.isNhentai = false,
  }) : assert(isNhentai || token.length == 10);

  static String fakeNhentaiToken(int gid) {
    String value = gid.toRadixString(36).toLowerCase().replaceAll('-', '0');
    if (value.length >= 10) {
      return value.substring(0, 10);
    }
    return value.padLeft(10, '0');
  }

  static GalleryUrl? tryParse(String url) {
    RegExp nhentaiRegExp = RegExp(r'https://nhentai\.net/g/(\d+)/?');
    Match? nhentaiMatch = nhentaiRegExp.firstMatch(url);
    if (nhentaiMatch != null) {
      int gid = int.parse(nhentaiMatch.group(1)!);
      return GalleryUrl(
        isEH: true,
        gid: gid,
        token: fakeNhentaiToken(gid),
        isNhentai: true,
      );
    }

    RegExp regExp =
        RegExp(r'https://e([-x])hentai\.org/g/(\d+)/([a-z0-9]{10})');
    Match? match = regExp.firstMatch(url);
    if (match == null) {
      return null;
    }

    return GalleryUrl(
      isEH: match.group(1) == '-',
      gid: int.parse(match.group(2)!),
      token: match.group(3)!,
    );
  }

  static GalleryUrl parse(String url) {
    RegExp nhentaiRegExp = RegExp(r'https://nhentai\.net/g/(\d+)/?');
    Match? nhentaiMatch = nhentaiRegExp.firstMatch(url);
    if (nhentaiMatch != null) {
      int gid = int.parse(nhentaiMatch.group(1)!);
      return GalleryUrl(
        isEH: true,
        gid: gid,
        token: fakeNhentaiToken(gid),
        isNhentai: true,
      );
    }

    RegExp regExp =
        RegExp(r'https://e([-x])hentai\.org/g/(\d+)/([a-z0-9]{10})');
    Match? match = regExp.firstMatch(url);
    if (match == null) {
      throw InternalException(message: 'Parse gallery url failed, url:$url');
    }

    return GalleryUrl(
      isEH: match.group(1) == '-',
      gid: int.parse(match.group(2)!),
      token: match.group(3)!,
    );
  }

  String get url {
    if (isNhentai) {
      return 'https://nhentai.net/g/$gid/';
    }

    return isEH
        ? 'https://e-hentai.org/g/$gid/$token/'
        : 'https://exhentai.org/g/$gid/$token/';
  }

  GalleryUrl copyWith({
    bool? isEH,
    int? gid,
    String? token,
    bool? isNhentai,
  }) {
    bool nextIsNhentai = isNhentai ?? this.isNhentai;

    return GalleryUrl(
      isEH: nextIsNhentai ? true : (isEH ?? this.isEH),
      gid: gid ?? this.gid,
      token: token ??
          (nextIsNhentai ? fakeNhentaiToken(gid ?? this.gid) : this.token),
      isNhentai: nextIsNhentai,
    );
  }

  @override
  String toString() {
    return 'GalleryUrl{isEH: $isEH, isNhentai: $isNhentai, gid: $gid, token: $token}';
  }
}
