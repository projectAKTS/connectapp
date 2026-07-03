import 'package:flutter/widgets.dart';

abstract interface class CallV2RouteSink {
  Future<void> open(Route<dynamic> route);
  Future<void> close();
}
