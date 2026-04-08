import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/dom.dart' as dom;
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/network/nh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/comment/nh_comment.dart';

import '../../../mixin/login_required_logic_mixin.dart';
import '../../../setting/user_setting.dart';
import '../../../utils/nh_spider_parser.dart';
import '../../../widget/nh_comment_dialog.dart';

class CommentPage extends StatefulWidget {
  const CommentPage({Key? key}) : super(key: key);

  @override
  _CommentPageState createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> with LoginRequiredMixin {
  late List<GalleryComment> comments = Get.arguments;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('allComments'.tr)),
      floatingActionButton: FloatingActionButton(
          onPressed: _handleTapAddCommentButton, child: const Icon(Icons.add)),
      body: ListView(
        padding: const EdgeInsets.only(top: 6, left: 8, right: 8, bottom: 200),
        controller: _scrollController,
        children: comments
            .map(
              (comment) => EHComment(
                comment: comment,
                inDetailPage: false,
                handleTapUpdateCommentButton: _handleTapUpdateCommentButton,
              ).marginOnly(bottom: 4),
            )
            .toList(),
      ).enableMouseDrag(),
    );
  }

  Future<void> _handleTapAddCommentButton() async {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    bool? success = await Get.dialog(
      EHCommentDialog(
        title: 'newComment'.tr,
        type: CommentDialogType.add,
      ),
    );

    if (success == null || success == false) {
      return;
    }

    List<GalleryComment> newComments = await ehRequest.requestDetailPage(
      galleryUrl:
          DetailsPageLogic.current!.state.galleryDetails?.galleryUrl.url ??
              DetailsPageLogic.current!.state.gallery!.galleryUrl.url,
      parser: EHSpiderParser.detailPage2Comments,
      useCacheIfAvailable: false,
    );

    setState(() {
      comments.clear();
      comments.addAll(newComments);
    });

    DetailsPageLogic.current?.update();
  }

  Future<void> _handleTapUpdateCommentButton(int commentId) async {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    GalleryComment comment = comments.firstWhere((c) => c.id == commentId);

    bool? success = await Get.dialog(
      EHCommentDialog(
        title: 'updateComment'.tr,
        initText: _parseCommentText(comment.content),
        type: CommentDialogType.update,
        commentId: commentId,
      ),
    );

    if (success == null || success == false) {
      return;
    }

    List<GalleryComment> newComments = await ehRequest.requestDetailPage(
      galleryUrl:
          DetailsPageLogic.current!.state.galleryDetails?.galleryUrl.url ??
              DetailsPageLogic.current!.state.gallery!.galleryUrl.url,
      parser: EHSpiderParser.detailPage2Comments,
      useCacheIfAvailable: false,
    );

    setState(() {
      comments.clear();
      comments.addAll(newComments);
    });

    DetailsPageLogic.current?.update();
  }

  String _parseCommentText(dom.Element element) {
    String result = '';

    for (dom.Node node in element.nodes) {
      if (node is dom.Text) {
        result += node.text;
        continue;
      }

      if (node is! dom.Element) {
        continue;
      }

      if (node.localName == 'br') {
        result += '\n';
      }

      result += node.text;
    }

    return result;
  }
}
