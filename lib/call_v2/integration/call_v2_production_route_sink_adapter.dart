import 'package:flutter/widgets.dart';

abstract interface class CallV2ProductionRouteSinkAdapter {
  bool get isDisposed;

  Future<void> push(Route<dynamic> route);

  Future<void> replace(Route<dynamic> route);

  Future<void> popCallV2Route();
}
