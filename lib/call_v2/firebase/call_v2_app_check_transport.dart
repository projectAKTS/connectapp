import 'package:firebase_app_check/firebase_app_check.dart';

abstract interface class CallV2AppCheckTransport {
  Future<String?> getToken();
}

class FirebaseCallV2AppCheckTransport implements CallV2AppCheckTransport {
  FirebaseCallV2AppCheckTransport({
    required FirebaseAppCheck appCheck,
  }) : _appCheck = appCheck;

  final FirebaseAppCheck _appCheck;

  @override
  Future<String?> getToken() {
    return _appCheck.getToken(false);
  }

  @override
  String toString() {
    return 'FirebaseCallV2AppCheckTransport()';
  }
}
