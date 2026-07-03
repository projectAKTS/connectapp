import 'package:flutter/widgets.dart';

import '../../call_v2_api.dart';

final class NonProductionCallV2FailurePlaceholder extends StatelessWidget {
  const NonProductionCallV2FailurePlaceholder({
    required this.errorCode,
    super.key,
  });

  final CallV2ClientErrorCode errorCode;

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Call V2 unavailable')),
    );
  }
}
