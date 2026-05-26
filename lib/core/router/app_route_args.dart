import 'dart:io';

import 'package:chat_app/data/models/user_model.dart';

class ChatRouteArgs {
  final UserModel otherUser;

  const ChatRouteArgs({required this.otherUser});
}

class ImagePreviewRouteArgs {
  final File file;
  final String initialCaption;

  const ImagePreviewRouteArgs({
    required this.file,
    required this.initialCaption,
  });
}

class ImageViewerRouteArgs {
  // Either `file` or `imageUrl` should be provided.
  final File? file;
  final String? imageUrl;
  final String? heroTag;

  const ImageViewerRouteArgs({
    this.file,
    this.imageUrl,
    this.heroTag,
  });
}

