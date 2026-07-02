import 'package:cloud_functions/cloud_functions.dart';

import 'call_v2_callable_transport.dart';

class FirebaseFunctionsCallV2Transport implements CallV2CallableTransport {
  FirebaseFunctionsCallV2Transport({
    required FirebaseFunctions functions,
    this.timeout = const Duration(seconds: 30),
  }) : _functions = functions;

  final FirebaseFunctions _functions;
  final Duration timeout;

  @override
  Future<Object?> call(
    String callableName,
    Map<String, Object?> request,
  ) async {
    final callable = _functions.httpsCallable(
      callableName,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call<Object?>(
      Map<String, Object?>.of(request),
    );
    return result.data;
  }
}
