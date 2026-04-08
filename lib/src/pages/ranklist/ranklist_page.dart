import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/pages/base/base_page.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_logic.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/utils/nhentai_jump_util.dart';
import 'package:jhentai/src/utils/route_util.dart';

class RanklistPage extends BasePage {
  const RanklistPage({
    Key? key,
    bool showMenuButton = false,
    bool showTitle = false,
    bool showScroll2TopButton = true,
  }) : super(
          key: key,
          showMenuButton: showMenuButton,
          showTitle: showTitle,
          showJumpButton: false,
          showScroll2TopButton: showScroll2TopButton,
        );

  @override
  RanklistPageLogic get logic =>
      Get.put<RanklistPageLogic>(RanklistPageLogic(), permanent: true);

  @override
  RanklistPageState get state => Get.find<RanklistPageLogic>().state;

  @override
  AppBar? buildAppBar(BuildContext context) {
    String ranklistLabel = _ranklistLabel(state.ranklistType);
    String title = state.searchQuery != null && state.searchQuery!.isNotEmpty
        ? '${state.searchQuery} $ranklistLabel ${'ranklist'.tr}'
        : '$ranklistLabel ${'ranklist'.tr}';

    return AppBar(
      title: Text(title, overflow: TextOverflow.ellipsis),
      centerTitle: true,
      leading: showMenuButton ? super.buildAppBarMenuButton(context) : null,
      actions: [
        ...super.buildAppBarActions(),
        if (ehRequest.isNhentaiMode)
          IconButton(
            icon: const Icon(Icons.pin_invoke_outlined),
            tooltip: 'jumpToGalleryId'.tr,
            onPressed: showNhentaiGalleryJumpDialog,
          ),
        IconButton(
          icon: Icon(
              state.searchQuery != null ? Icons.search : Icons.search_outlined),
          tooltip: 'filterTag'.tr,
          onPressed: () => _showSearchDialog(context),
        ),
        PopupMenuButton(
          tooltip: '',
          initialValue: state.ranklistType,
          onSelected: logic.handleChangeRanklist,
          itemBuilder: (BuildContext context) {
            if (ehRequest.isNhentaiMode) {
              return <PopupMenuEntry<RanklistType>>[
                PopupMenuItem<RanklistType>(
                    value: RanklistType.allTime,
                    child: Center(
                        child: Text(_ranklistLabel(RanklistType.allTime)))),
                PopupMenuItem<RanklistType>(
                    value: RanklistType.month,
                    child: Center(
                        child: Text(_ranklistLabel(RanklistType.month)))),
                PopupMenuItem<RanklistType>(
                    value: RanklistType.week,
                    child:
                        Center(child: Text(_ranklistLabel(RanklistType.week)))),
                PopupMenuItem<RanklistType>(
                    value: RanklistType.day,
                    child:
                        Center(child: Text(_ranklistLabel(RanklistType.day)))),
              ];
            }

            return <PopupMenuEntry<RanklistType>>[
              PopupMenuItem<RanklistType>(
                  value: RanklistType.allTime,
                  child: Center(child: Text('allTime'.tr))),
              PopupMenuItem<RanklistType>(
                  value: RanklistType.year,
                  child: Center(child: Text('year'.tr))),
              PopupMenuItem<RanklistType>(
                  value: RanklistType.month,
                  child: Center(child: Text('month'.tr))),
              PopupMenuItem<RanklistType>(
                  value: RanklistType.day,
                  child: Center(child: Text('day'.tr))),
            ];
          },
        ),
      ],
    );
  }

  void _showSearchDialog(BuildContext context) {
    TextEditingController controller =
        TextEditingController(text: state.searchQuery ?? '');

    Get.dialog(
      AlertDialog(
        title: Text('filterTag'.tr),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'filterTag'.tr,
            isDense: true,
          ),
          onSubmitted: (_) => _confirmSearch(controller),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              logic.handleClearSearch();
            },
            child: Text('delete'.tr),
          ),
          TextButton(
            onPressed: backRoute,
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => _confirmSearch(controller),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmSearch(TextEditingController controller) {
    String query = controller.text.trim();
    Get.back();
    logic.handleSearchQueryChanged(query.isEmpty ? null : query);
  }

  String _ranklistLabel(RanklistType type) {
    if (!ehRequest.isNhentaiMode) {
      return type.name.tr;
    }

    switch (type) {
      case RanklistType.allTime:
        return 'allTime'.tr;
      case RanklistType.year:
        return 'year'.tr;
      case RanklistType.month:
        return 'sortMonth'.tr;
      case RanklistType.week:
        return 'sortWeek'.tr;
      case RanklistType.day:
        return 'sortToday'.tr;
    }
  }
}
