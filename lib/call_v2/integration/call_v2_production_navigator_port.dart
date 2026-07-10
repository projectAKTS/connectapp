import 'package:flutter/widgets.dart';

abstract interface class CallV2ProductionNavigatorPort {
  Future<void> push(Route<dynamic> route);

  Future<void> pushReplacement(Route<dynamic> route);

  bool canPop();

  void pop();
}
