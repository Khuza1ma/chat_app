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
