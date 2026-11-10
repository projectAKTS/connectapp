import 'dart:io';

import 'package:flutter/services.dart';

/// Makes a smaller copy of a post video before upload, using the phone's own
/// encoder (AVFoundation on iOS, Media3 on Android): 720p, or 540p for
/// clips over a minute. Phone videos are often hundreds of MB, which costs
/// storage and is slow to upload and to watch.
class VideoCompressor {
  static const _channel = MethodChannel('connectapp/videoCompress');

  /// The smaller copy, or null to upload [input] as it is (no encoder,
  /// failure, timeout, or a copy that is not clearly smaller).
  static Future<File?> compress(File input) async {
    try {
      final path = await _channel.invokeMethod<String>(
          'compress', {'path': input.path}).timeout(const Duration(minutes: 5));
      if (path == null || path.isEmpty) return null;
      final out = File(path);
      if (!await out.exists()) return null;
      if (await out.length() >= await input.length() * 0.9) {
        await out.delete().catchError((_) => out);
        return null;
      }
      return out;
    } catch (_) {
      return null;
    }
  }
}
