import 'package:chat_app/domain/entities/message.dart';
import 'package:chat_app/domain/repositories/chat_repository.dart';

class GetMessagesUseCase {
  final ChatRepository repository;

  GetMessagesUseCase(this.repository);

  Stream<List<MessageEntity>> call({int limit = 20}) {
    return repository.getMessages(limit: limit);
  }
}
