import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class PostImageViewer extends StatelessWidget {
  final String url;
  const PostImageViewer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(url),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
        ),
      ),
    );
  }
}
