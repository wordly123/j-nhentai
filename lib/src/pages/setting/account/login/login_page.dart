import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_logic.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_state.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class LoginPage extends StatelessWidget {
  final LoginPageLogic logic = Get.put<LoginPageLogic>(LoginPageLogic());
  final LoginPageState state = Get.find<LoginPageLogic>().state;

  LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        centerTitle: true,
        title: Text('nhentaiAuth'.tr),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'nhApiKeyTutorial'.tr,
                      style: TextStyle(
                          color: UIConfig.loginPageFormHintColor(context),
                          fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _buildApiKeyField(context),
                    const SizedBox(height: 20),
                    _buildLoginButton(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyField(BuildContext context) {
    return TextFormField(
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => logic.handleLogin(),
      onChanged: (v) => state.apiKey = v,
      decoration: InputDecoration(
        labelText: 'apiKeyLabel'.tr,
        hintText: 'apiKeyRequiredHint'.tr,
        prefixIcon: const Icon(Icons.vpn_key_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: logic.handleLogin,
        child: GetBuilder<LoginPageLogic>(
          id: LoginPageLogic.loadingStateId,
          builder: (_) => LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: state.loginState,
            indicatorRadius: 10,
            indicatorColor: UIConfig.loginPageIndicatorColor(context),
            idleWidgetBuilder: () => Text('saveApiKey'.tr),
            successWidgetBuilder: () => const Icon(Icons.check),
            errorWidgetBuilder: () => Text('reload'.tr),
          ),
        ),
      ),
    );
  }
}
