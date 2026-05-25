import 'package:dartz/dartz.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/domain/entities/message.dart';
import 'dart:io';

abstract class ChatRepository {
  Stream<List<MessageEntity>> getMessages({int limit = 20});
  Future<Either<Failure, void>> sendMessage(MessageEntity message, File? image);
  Future<List<MessageEntity>> getOlderMessages(DateTime before, {int limit = 20});
  Future<Either<Failure, void>> deleteMessages(String chatId, List<String> messageIds);
}
