import 'package:get/get.dart';

enum Side {
  left,
  right,
  fullScreen,
}

class NHPage extends GetPage {
  /// in tablet layout, the side this page on.
  final Side side;

  /// used when pushing a new route to right screen
  final bool offAllBefore;

  NHPage({
    required super.name,
    required super.page,
    this.side = Side.right,
    this.offAllBefore = true,
    super.transition,
    super.popGesture,
  });
}
