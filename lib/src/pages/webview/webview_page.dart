import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef OnPageStartedCallback = Future<void> Function(
    String url, WebViewController controller);

class WebviewPage extends StatefulWidget {
  const WebviewPage({Key? key}) : super(key: key);

  @override
  _WebviewPageState createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  late final String title;
  late final Function? pageStartedCallback;
  late final Function? pageFinishedCallback;
  late final WebViewController controller;

  LoadingState loadingState = LoadingState.loading;

  @override
  void initState() {
    super.initState();

    title = Get.arguments['title'];

    if (Get.arguments is Map && Get.arguments['onPageStarted'] is Function) {
      pageStartedCallback = Get.arguments['onPageStarted'];
    } else {
      pageStartedCallback = null;
    }

    if (Get.arguments is Map && Get.arguments['onPageFinished'] is Function) {
      pageFinishedCallback = Get.arguments['onPageFinished'];
    } else {
      pageFinishedCallback = null;
    }

    CookieUtil.parse2Cookies(Get.arguments['cookies']).forEach((cookie) {
      WebViewCookieManager().setCookie(
        WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: Uri.parse(Get.arguments['url']).host,
        ),
      );
    });

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) async {
            if (pageStartedCallback == null) {
              return;
            }

            try {
              await Future.sync(() => pageStartedCallback!.call(url, controller));
            } catch (e, s) {
              log.error('Webview onPageStarted callback failed', e, s);
            }
          },
          onPageFinished: (String url) async {
            setStateSafely(() => loadingState = LoadingState.success);
            if (pageFinishedCallback == null) {
              return;
            }

            try {
              await Future.sync(
                  () => pageFinishedCallback!.call(url, controller));
            } catch (e, s) {
              log.error('Webview onPageFinished callback failed', e, s);
            }
          },
          onWebResourceError: (_) =>
              setStateSafely(() => loadingState = LoadingState.success),
        ),
      )
      ..loadRequest(Uri.parse(Get.arguments['url']));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: LoadingStateIndicator(
          loadingState: loadingState,
          successWidgetBuilder: () => Text(title),
        ).paddingOnly(right: 40),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
