import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/domain/entities/message.dart';
import 'package:chat_app/domain/repositories/chat_repository.dart';

class SendMessageUseCase {
  final ChatRepository repository;

  SendMessageUseCase(this.repository);

  Future<Either<Failure, void>> call(MessageEntity message, File? image) {
    return repository.sendMessage(message, image);
  }
}
