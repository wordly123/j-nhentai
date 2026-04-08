import 'package:flutter/cupertino.dart';

import '../../../../mixin/scroll_to_top_state_mixin.dart';

const String kDownloadRootGroup = '';

mixin GridBasePageState implements Scroll2TopStateMixin {
  bool inEditMode = false;

  String currentGroup = kDownloadRootGroup;

  bool get isAtRoot => currentGroup == kDownloadRootGroup;

  List<String> get allRootGroups;

  List get currentGalleryObjects => galleryObjectsWithGroup(currentGroup);

  List galleryObjectsWithGroup(String groupName);

  final ScrollController rootScrollController = ScrollController();
  final ScrollController galleryScrollController = ScrollController();

  @override
  ScrollController get scrollController =>
      isAtRoot ? rootScrollController : galleryScrollController;
}
