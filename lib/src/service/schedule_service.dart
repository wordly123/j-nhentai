import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:extended_image/extended_image.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/nh_spider_parser.dart';
import 'package:jhentai/src/utils/snack_util.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:retry/retry.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../model/gallery_metadata.dart';
import 'jh_service.dart';
import 'log.dart';

ScheduleService scheduleService = ScheduleService();

class ScheduleService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {
    Timer(const Duration(seconds: 10), refreshGalleryTags);
    Timer(const Duration(seconds: 5), clearOutdatedImageCache);

    Timer(const Duration(seconds: 5), checkEHEvent);
    Timer.periodic(const Duration(minutes: 5), (_) => checkEHEvent());
  }

  Future<void> refreshGalleryTags() async {
    int pageNo = 1;
    List<GalleryDownloadedData> gallerys =
        await GalleryDao.selectGallerysForTagRefresh(pageNo, 25);
    while (gallerys.isNotEmpty) {
      try {
        List<GalleryMetadata> metadatas =
            await ehRequest.requestGalleryMetadatas<List<GalleryMetadata>>(
          list: gallerys.map((a) => (gid: a.gid, token: a.token)).toList(),
          parser: EHSpiderParser.galleryMetadataJson2GalleryMetadatas,
        );

        await GalleryDao.batchUpdateGallery(
          metadatas
              .map(
                (m) => GalleryDownloadedCompanion(
                  gid: Value(m.galleryUrl.gid),
                  tags: Value(tagMap2TagString(m.tags)),
                  tagRefreshTime: Value(DateTime.now().toString()),
                ),
              )
              .toList(),
        );
        log.trace(
            'refreshGalleryTags success, pageNo: $pageNo, archives: ${gallerys.map((a) => a.gid).toList()}');
      } catch (e) {
        log.warning(
            'refreshGalleryTags error, gallerys: ${gallerys.map((a) => (
                  gid: a.gid,
                  token: a.token
                )).toList()}',
            e,
            true);
      }

      pageNo++;
      gallerys = await GalleryDao.selectGallerysForTagRefresh(pageNo, 25);
    }
  }

  Future<void> clearOutdatedImageCache() async {
    Directory cacheImageDirectory = Directory(
        join((await getTemporaryDirectory()).path, cacheImageFolderName));

    int count = 0;
    cacheImageDirectory.list().forEach((FileSystemEntity entity) {
      if (entity is File &&
          DateTime.now().difference(entity.lastAccessedSync()) >
              networkSetting.cacheImageExpireDuration.value) {
        entity.delete();
        count++;
      }
    }).then(
        (_) => log.info('Clear outdated image cache success, count: $count'));
  }

  Future<void> checkEHEvent() async {
    if (!userSetting.hasLoggedIn()) {
      return;
    }

    if (!preferenceSetting.showHVInfo.value &&
        !preferenceSetting.showDawnInfo.value) {
      return;
    }

    ({String? dawnInfo, String? hvUrl}) eventInfo;
    try {
      eventInfo = await retry(
        () => ehRequest.requestNews(EHSpiderParser.newsPage2Event),
        retryIf: (e) => e is DioException,
        maxAttempts: 3,
      );
    } catch (e) {
      log.warning('ScheduleService checkDawn failed', e);
      return;
    }

    if (preferenceSetting.showDawnInfo.value && eventInfo.dawnInfo != null) {
      log.info('Check dawn success: ${eventInfo.dawnInfo}');
      snack(
        'dawnOfaNewDay'.tr,
        eventInfo.dawnInfo!,
        isShort: false,
      );
    }

    if (preferenceSetting.showHVInfo.value && eventInfo.hvUrl != null) {
      log.info('Encounter a monster: ${eventInfo.hvUrl}');
      snack(
        'encounterMonster'.tr,
        'encounterMonsterHint'.tr,
        onPressed: () => launchUrlString(eventInfo.hvUrl!,
            mode: LaunchMode.externalApplication),
        isShort: false,
      );
    }
  }
}
