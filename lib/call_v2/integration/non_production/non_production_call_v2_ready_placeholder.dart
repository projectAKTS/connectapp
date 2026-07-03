import 'package:flutter/widgets.dart';

final class NonProductionCallV2ReadyPlaceholder extends StatelessWidget {
  const NonProductionCallV2ReadyPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Call V2 ready placeholder')),
    );
  }
}
