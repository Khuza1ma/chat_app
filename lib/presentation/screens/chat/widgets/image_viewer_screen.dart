import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ImageViewerScreen extends StatelessWidget {
  final File? file;
  final String? imageUrl;
  final String? heroTag;

  const ImageViewerScreen({
    super.key,
    this.file,
    this.imageUrl,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag ?? '__image_viewer_hero__${imageUrl ?? file?.path}',
          child: InteractiveViewer(
            maxScale: 4.0,
            minScale: 0.5,
            child: _buildImage(context),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (file != null) {
      return Image.file(file!, fit: BoxFit.contain);
    }

    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.contain,
        placeholder: (ctx, url) => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ),
        errorWidget: (ctx, url, err) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
      );
    }

    return const SizedBox.shrink();
  }
}

