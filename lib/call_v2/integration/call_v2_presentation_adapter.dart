import '../ui/call_v2_route_intent.dart';

abstract interface class CallV2PresentationAdapter {
  Future<void> handle(CallV2RouteIntent intent);
  Future<void> dispose();
}
