import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/video_compressor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('connectapp/videoCompress');
  late Directory dir;
  late File input;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vc');
    input = File('${dir.path}/in.mov')..writeAsBytesSync(List.filled(1000, 1));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await dir.delete(recursive: true);
  });

  void answer(Object? Function(MethodCall) f) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async => f(c));

  test('a clearly smaller copy is used', () async {
    final out = File('${dir.path}/out.mp4')..writeAsBytesSync(List.filled(300, 1));
    answer((c) => c.arguments['path'] == input.path ? out.path : null);
    expect((await VideoCompressor.compress(input))?.path, out.path);
  });

  test('the original is kept when the copy is not smaller', () async {
    final out = File('${dir.path}/out.mp4')..writeAsBytesSync(List.filled(950, 1));
    answer((_) => out.path);
    expect(await VideoCompressor.compress(input), isNull);
    expect(out.existsSync(), isFalse);
  });

  test('the original is kept when the phone cannot compress', () async {
    answer((_) => null);
    expect(await VideoCompressor.compress(input), isNull);
    answer((_) => throw PlatformException(code: 'x'));
    expect(await VideoCompressor.compress(input), isNull);
  });
}
