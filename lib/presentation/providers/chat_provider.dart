import 'package:flutter/material.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'dart:io';

class ChatProvider extends ChangeNotifier {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;

  List<MessageEntity> _messages = [];
  bool _isLoading = false;

  ChatProvider({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
  });

  List<MessageEntity> get messages => _messages;
  bool get isLoading => _isLoading;

  void listenToMessages() {
    getMessagesUseCase().listen((messages) {
      _messages = messages;
      notifyListeners();
    });
  }

  Future<void> sendMessage(String text, {File? image}) async {
  }

  Future<void> loadOlderMessages() async {
  }
}
