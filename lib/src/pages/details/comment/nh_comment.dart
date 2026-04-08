import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery_image_page_url.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/gallery_image/gallery_image_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/date_util.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../model/gallery_comment.dart';
import '../../../service/log.dart';
import '../../../utils/route_util.dart';

const double imageMinHeight = 100;

class EHComment extends StatefulWidget {
  final GalleryComment comment;
  final bool inDetailPage;
  final Function(int commentId)? handleTapUpdateCommentButton;

  const EHComment({
    Key? key,
    required this.comment,
    required this.inDetailPage,
    this.handleTapUpdateCommentButton,
  }) : super(key: key);

  @override
  _EHCommentState createState() => _EHCommentState();
}

class _EHCommentState extends State<EHComment> {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EHCommentHeader(
            inDetailPage: widget.inDetailPage,
            username: widget.comment.username,
            commentTime: widget.comment.time,
            fromMe: widget.comment.fromMe,
          ),
          Flexible(
            child: _EHCommentTextBody(
              inDetailPage: widget.inDetailPage,
              element: widget.comment.content,
            ).paddingOnly(top: 4, bottom: 8),
          ),
          _EHCommentFooter(
            inDetailPage: widget.inDetailPage,
            commentId: widget.comment.id,
            lastEditTime: widget.comment.lastEditTime,
            fromMe: widget.comment.fromMe,
            handleTapUpdateCommentButton: widget.handleTapUpdateCommentButton,
          ),
        ],
      ).paddingOnly(left: 8, right: 8, top: 8, bottom: 6),
    );
  }
}

class _EHCommentHeader extends StatelessWidget {
  final bool inDetailPage;
  final String? username;
  final String commentTime;
  final bool fromMe;

  const _EHCommentHeader({
    Key? key,
    required this.inDetailPage,
    required this.username,
    required this.commentTime,
    required this.fromMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          (username ?? 'unknownUser'.tr) + (fromMe ? ' (${'you'.tr})' : ''),
          style: TextStyle(
            fontSize: inDetailPage
                ? UIConfig.commentAuthorTextSizeInDetailPage
                : UIConfig.commentAuthorTextSizeInCommentPage,
            fontWeight: FontWeight.bold,
            color: username == null
                ? UIConfig.commentUnknownAuthorTextColor(context)
                : fromMe
                    ? UIConfig.commentOwnAuthorTextColor(context)
                    : UIConfig.commentOtherAuthorTextColor(context),
          ),
        ),
        Text(
          preferenceSetting.showUtcTime.isTrue
              ? commentTime
              : DateUtil.transformUtc2LocalTimeString(commentTime),
          style: TextStyle(
            fontSize: inDetailPage
                ? UIConfig.commentTimeTextSizeInDetailPage
                : UIConfig.commentTimeTextSizeInCommentPage,
            color: UIConfig.commentTimeTextColor(context),
          ),
        ),
      ],
    );
  }
}

class _EHCommentTextBody extends StatelessWidget {
  final bool inDetailPage;
  final dom.Element element;

  const _EHCommentTextBody({
    Key? key,
    required this.inDetailPage,
    required this.element,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget widget = Container(
      alignment: Alignment.topLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: inDetailPage
                ? UIConfig.commentBodyTextSizeInDetailPage
                : UIConfig.commentBodyTextSizeInCommentPage,
            color: UIConfig.commentBodyTextColor(context),
            height: 1.5,
          ),
          children: element.nodes.map((tag) => buildTag(context, tag)).toList(),
        ),
        maxLines: inDetailPage ? 5 : null,
        overflow: inDetailPage ? TextOverflow.ellipsis : null,
      ),
    );

    if (!inDetailPage) {
      widget = SelectionArea(child: widget);
    }

    return widget;
  }

  /// Maybe i can rewrite it by `Chain of Responsibility Pattern`
  InlineSpan buildTag(BuildContext context, dom.Node node) {
    /// plain text
    if (node is dom.Text) {
      return _buildText(context, node.text);
    }

    /// unknown node
    if (node is! dom.Element) {
      log.error('Can not parse html node: $node');
      log.uploadError(Exception('Can not parse html node'),
          extraInfos: {'node': node});
      return TextSpan(text: node.text);
    }

    /// advertisement
    if (node.localName == 'div' && node.attributes['id'] == 'spa') {
      return const TextSpan();
    }

    if (node.localName == 'br') {
      return const TextSpan(text: '\n');
    }

    /// span
    if (node.localName == 'span') {
      return TextSpan(
        style: _parseTextStyle(node),
        children:
            node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// strong
    if (node.localName == 'strong') {
      return TextSpan(
        style: const TextStyle(fontWeight: FontWeight.bold),
        children:
            node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// em
    if (node.localName == 'em') {
      return TextSpan(
        style: const TextStyle(fontStyle: FontStyle.italic),
        children:
            node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// del
    if (node.localName == 'del') {
      return TextSpan(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
        children:
            node.nodes.map((childTag) => buildTag(context, childTag)).toList(),
      );
    }

    /// image
    if (node.localName == 'img') {
      /// not show image in detail page
      if (inDetailPage) {
        return TextSpan(
            text: '[${'image'.tr}]  ',
            style: const TextStyle(color: UIConfig.commentLinkColor));
      }

      String url =
          node.attributes['src']!.replaceAll('s.exhentai.org', 'ehgt.org');
      return WidgetSpan(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _computeImageMaxWidth(constraints, node),
              ),
              child: ExtendedImage.network(
                url,
                handleLoadingProgress: true,
                loadStateChanged: (ExtendedImageState state) {
                  switch (state.extendedImageLoadState) {
                    case LoadState.loading:
                      return Center(child: UIConfig.loadingAnimation(context));
                    case LoadState.failed:
                      return Center(
                        child: GestureDetector(
                            child:
                                const Icon(Icons.sentiment_very_dissatisfied),
                            onTap: state.reLoadImage),
                      );
                    default:
                      return null;
                  }
                },
              ),
            );
          },
        ),
      );
    }

    /// link
    if (node.localName == 'a') {
      Widget child = Wrap(
        children: node.nodes
            .map(
              (childTag) => Text.rich(
                buildTag(context, childTag),
                style: const TextStyle(
                    color: UIConfig.commentLinkColor,
                    fontSize: UIConfig.commentLinkFontSize),
              ),
            )
            .toList(),
      );

      if (!inDetailPage) {
        child = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTapUrl(node.attributes['href'] ?? node.text),
          child: child,
        );
      }

      return WidgetSpan(child: child);
    }

    log.error('Can not parse html tag: $node');
    log.uploadError(Exception('Can not parse html tag'),
        extraInfos: {'node': node});
    return TextSpan(text: node.text);
  }

  InlineSpan _buildText(BuildContext context, String text) {
    RegExp reg = RegExp(r'(https?:\/\/((\w|=|\?|\.|\/|&|-|#|%|@|~|\+|:)+))');
    Match? match = reg.firstMatch(text);

    if (match == null) {
      return TextSpan(text: text);
    }

    /// some url link doesn't be wrapped in <a href='xxx'></a>, we manually render it as a url.
    if (match.start == 0) {
      return TextSpan(
        text: match.group(0),
        style: const TextStyle(
            color: UIConfig.commentLinkColor,
            fontSize: UIConfig.commentLinkFontSize),
        recognizer: inDetailPage
            ? null
            : (TapGestureRecognizer()
              ..onTap = () => _handleTapUrl(match.group(0)!)),
        children: [_buildText(context, text.substring(match.end))],
      );
    }

    return TextSpan(
      text: text.substring(0, match.start),
      children: [_buildText(context, text.substring(match.start))],
    );
  }

  TextStyle? _parseTextStyle(dom.Element node) {
    final style = node.attributes['style'];
    if (style == null) {
      return null;
    }

    final Map<String, String> styleMap = Map.fromEntries(
      style
          .split(';')
          .map((e) => e.split(':'))
          .where((e) => e.length == 2)
          .map((e) => MapEntry(e[0].trim(), e[1].trim())),
    );

    return TextStyle(
      color: styleMap['color'] == null
          ? null
          : Color(int.parse(styleMap['color']!.substring(1), radix: 16) +
              0xFF000000),
      fontWeight: styleMap['font-weight'] == 'bold' ? FontWeight.bold : null,
      fontStyle: styleMap['font-style'] == 'italic' ? FontStyle.italic : null,
      decoration: styleMap['text-decoration'] == 'underline'
          ? TextDecoration.underline
          : null,
    );
  }

  /// make sure align several images into one line
  double _computeImageMaxWidth(
      BoxConstraints constraints, dom.Element imageElement) {
    /// wrapped in a <a>
    if (imageElement.parent?.localName == 'a' &&
        imageElement.parent!.children.length == 1) {
      imageElement = imageElement.parent!;
    }

    int previousImageCount = 0;
    int followingImageCount = 0;
    dom.Element? previousElement = imageElement.previousElementSibling;
    dom.Element? nextElement = imageElement.nextElementSibling;

    while (previousElement != null && _containsImage(previousElement)) {
      previousImageCount++;
      previousElement = previousElement.previousElementSibling;
    }
    while (nextElement != null && _containsImage(nextElement)) {
      followingImageCount++;
      nextElement = nextElement.nextElementSibling;
    }

    int showImageCount = previousImageCount + followingImageCount + 1;
    showImageCount = showImageCount < 3 ? 3 : showImageCount;
    showImageCount = showImageCount > 5 ? 5 : showImageCount;

    /// tolerance = 3
    return constraints.maxWidth / showImageCount - 3;
  }

  bool _containsImage(dom.Element element) {
    if (element.localName == 'img') {
      return true;
    }

    if (element.children.isEmpty) {
      return false;
    }

    return element.children.any(_containsImage);
  }

  Future<bool> _handleTapUrl(String url) async {
    GalleryUrl? galleryUrl = GalleryUrl.tryParse(url);
    if (galleryUrl != null) {
      toRoute(
        Routes.details,
        arguments: DetailsPageArgument(galleryUrl: galleryUrl),
        offAllBefore: false,
      );
      return true;
    }

    GalleryImagePageUrl? galleryImagePageUrl =
        GalleryImagePageUrl.tryParse(url);
    if (galleryImagePageUrl != null) {
      toRoute(
        Routes.imagePage,
        arguments:
            GalleryImagePageArgument(galleryImagePageUrl: galleryImagePageUrl),
        offAllBefore: false,
      );
      return true;
    }

    return await launchUrlString(url, mode: LaunchMode.externalApplication);
  }
}

class _EHCommentFooter extends StatelessWidget {
  final bool inDetailPage;
  final int commentId;
  final String? lastEditTime;
  final bool fromMe;
  final Function(int commentId)? handleTapUpdateCommentButton;

  const _EHCommentFooter({
    Key? key,
    required this.inDetailPage,
    required this.commentId,
    this.lastEditTime,
    required this.fromMe,
    this.handleTapUpdateCommentButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (lastEditTime?.isNotEmpty ?? false)
          Text(
            '${'lastEditedOn'.tr}: ${preferenceSetting.showUtcTime.isTrue ? lastEditTime : DateUtil.transformUtc2LocalTimeString(lastEditTime!)}',
            style: TextStyle(
                fontSize: UIConfig.commentLastEditTimeTextSize,
                color: UIConfig.commentFooterTextColor(context)),
          ),
        const Expanded(child: SizedBox()),
        if (!inDetailPage && fromMe)
          GestureDetector(
            onTap: () => handleTapUpdateCommentButton?.call(commentId),
            child: const Icon(Icons.edit_note,
                size: UIConfig.commentButtonSizeInCommentPage),
          ),
      ],
    );
  }
}
