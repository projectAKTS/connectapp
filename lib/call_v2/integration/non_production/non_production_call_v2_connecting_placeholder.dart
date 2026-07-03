import 'package:flutter/widgets.dart';

final class NonProductionCallV2ConnectingPlaceholder extends StatelessWidget {
  const NonProductionCallV2ConnectingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Call V2 connecting placeholder')),
    );
  }
}
