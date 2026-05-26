import 'dart:io';

import 'package:chat_app/data/models/message_model.dart';

enum MessagePosition { first, middle, last, isolated }

class ChatPendingMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final File localImage;
  final DateTime timestamp;
  final String? uploadedImageUrl;

  const ChatPendingMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.localImage,
    required this.timestamp,
    this.uploadedImageUrl,
  });

  ChatPendingMessage copyWith({String? uploadedImageUrl}) {
    return ChatPendingMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      text: text,
      localImage: localImage,
      timestamp: timestamp,
      uploadedImageUrl: uploadedImageUrl ?? this.uploadedImageUrl,
    );
  }
}

class ChatDisplayMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final File? localImage;
  final DateTime timestamp;
  final bool isPending;

  const ChatDisplayMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.imageUrl,
    required this.localImage,
    required this.timestamp,
    required this.isPending,
  });

  factory ChatDisplayMessage.fromRemote(MessageModel message) {
    return ChatDisplayMessage(
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      text: message.text,
      imageUrl: message.imageUrl,
      localImage: null,
      timestamp: message.timestamp,
      isPending: false,
    );
  }

  factory ChatDisplayMessage.fromPending(ChatPendingMessage message) {
    return ChatDisplayMessage(
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      text: message.text,
      imageUrl: message.uploadedImageUrl,
      localImage: message.localImage,
      timestamp: message.timestamp,
      isPending: true,
    );
  }
}
