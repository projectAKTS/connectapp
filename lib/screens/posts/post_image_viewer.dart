import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PostImageViewer extends StatelessWidget {
  final String? url; // ✅ for Home
  final File? file;  // ✅ for Create preview

  const PostImageViewer({
    super.key,
    this.url,
    this.file,
  }) : assert(url != null || file != null, 'Provide either url or file');

  @override
  Widget build(BuildContext context) {
    final ImageProvider provider =
        file != null ? FileImage(file!) : NetworkImage(url!);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: PhotoView(
          imageProvider: provider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      ),
    );
  }
}
