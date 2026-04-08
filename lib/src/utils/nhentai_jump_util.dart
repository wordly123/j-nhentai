import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

int? parseNhentaiGalleryId(String raw) {
  String normalized = raw.trim();
  if (!RegExp(r'^\d+$').hasMatch(normalized)) {
    return null;
  }

  int? gid = int.tryParse(normalized);
  if (gid == null || gid <= 0) {
    return null;
  }

  return gid;
}

GalleryUrl? buildNhentaiGalleryUrlFromIdInput(String raw) {
  int? gid = parseNhentaiGalleryId(raw);
  if (gid == null) {
    return null;
  }

  return GalleryUrl(
    isEH: true,
    gid: gid,
    token: GalleryUrl.fakeNhentaiToken(gid),
    isNhentai: true,
  );
}

Future<void> jumpToNhentaiGalleryId(int gid) async {
  await toRoute(
    Routes.details,
    arguments: DetailsPageArgument(
      galleryUrl: GalleryUrl(
        isEH: true,
        gid: gid,
        token: GalleryUrl.fakeNhentaiToken(gid),
        isNhentai: true,
      ),
    ),
    preventDuplicates: false,
  );
}

Future<void> showNhentaiGalleryJumpDialog() async {
  final TextEditingController controller = TextEditingController();

  int? gid = await Get.dialog<int>(
    AlertDialog(
      title: Text('jumpToGalleryId'.tr),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: 'nhGalleryIdHint'.tr,
          labelText: 'galleryId'.tr,
        ),
        onSubmitted: (_) =>
            backRoute(result: parseNhentaiGalleryId(controller.text)),
      ),
      actions: [
        TextButton(
          onPressed: backRoute,
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () =>
              backRoute(result: parseNhentaiGalleryId(controller.text)),
          child: Text('OK'.tr),
        ),
      ],
    ),
  );

  if (gid == null) {
    if (controller.text.trim().isNotEmpty) {
      toast('invalidNhGalleryId'.tr, isShort: false);
    }
    return;
  }

  await jumpToNhentaiGalleryId(gid);
}
