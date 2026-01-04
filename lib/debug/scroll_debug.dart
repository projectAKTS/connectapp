import 'package:flutter/material.dart';

void safeJumpTo(ScrollController c, double offset, {String tag = ''}) {
  debugPrint('🧨 jumpTo($offset) tag=$tag hasClients=${c.hasClients} '
      'old=${c.hasClients ? c.offset : 'noClients'}');
  debugPrintStack(label: 'STACK jumpTo tag=$tag');
  if (c.hasClients) c.jumpTo(offset);
}

Future<void> safeAnimateTo(
  ScrollController c,
  double offset, {
  String tag = '',
  Duration duration = const Duration(milliseconds: 250),
  Curve curve = Curves.easeOut,
}) async {
  debugPrint('🧨 animateTo($offset) tag=$tag hasClients=${c.hasClients}');
  debugPrintStack(label: 'STACK animateTo tag=$tag');
  if (c.hasClients) {
    await c.animateTo(offset, duration: duration, curve: curve);
  }
}
