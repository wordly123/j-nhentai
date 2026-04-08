import 'dart:async';

import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/pages/ranklist/ranklist_page_state.dart';
import 'package:jhentai/src/utils/nh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../service/log.dart';
import '../base/old_base_page_logic.dart';

class RanklistPageLogic extends OldBasePageLogic {
  @override
  final RanklistPageState state = RanklistPageState();

  @override
  bool get useSearchConfig => false;

  Future<void> handleChangeRanklist(RanklistType newType) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }
    if (newType == state.ranklistType) {
      return;
    }

    state.ranklistType = newType;
    super.handleClearAndRefresh();
  }

  Future<void> handleSearchQueryChanged(String? query) async {
    if (state.loadingState == LoadingState.loading) {
      return;
    }

    String? trimmed = query?.trim();
    if (trimmed != null && trimmed.isEmpty) {
      trimmed = null;
    }

    if (trimmed == state.searchQuery) {
      return;
    }

    state.searchQuery = trimmed;
    super.handleClearAndRefresh();
  }

  Future<void> handleClearSearch() async {
    if (state.searchQuery == null) {
      return;
    }
    state.searchQuery = null;
    super.handleClearAndRefresh();
  }

  @override
  Future<List<dynamic>> getGallerysAndPageInfoByPage(int pageIndex) async {
    log.info(
        'Get ranklist data, type:${state.ranklistType.name}, query:${state.searchQuery}, pageIndex:$pageIndex');

    return await ehRequest.requestRanklistPage(
      ranklistType: state.ranklistType,
      pageNo: pageIndex,
      searchQuery: state.searchQuery,
      parser: EHSpiderParser.ranklistPage2GalleryPageInfo,
    );
  }
}
