import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/message_model.dart';
import '../sources/firebase_chat_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseChatSource dataSource;

  ChatRepositoryImpl(this.dataSource);

  @override
  Stream<List<MessageEntity>> getMessages({int limit = 20}) {
    return dataSource.getMessages(limit);
  }

  @override
  Future<Either<Failure, void>> sendMessage(MessageEntity message, File? image) async {
    try {
      String? imageUrl;
      if (image != null) {
        imageUrl = await dataSource.uploadImage(image);
      }

      final messageModel = MessageModel(
        id: message.id,
        senderId: message.senderId,
        senderName: message.senderName,
        text: message.text,
        imageUrl: imageUrl,
        timestamp: message.timestamp,
      );

      await dataSource.sendMessage(messageModel);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<List<MessageEntity>> getOlderMessages(DateTime before, {int limit = 20}) {
    return dataSource.getOlderMessages(before, limit);
  }
}
