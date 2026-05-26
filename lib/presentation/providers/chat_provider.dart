import 'package:flutter/material.dart';
import 'package:chat_app/domain/entities/message.dart';
import 'package:chat_app/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/domain/usecases/send_message_usecase.dart';
import 'dart:io';

class ChatProvider extends ChangeNotifier {
  final GetMessagesUseCase getMessagesUseCase;
  final SendMessageUseCase sendMessageUseCase;

  List<MessageEntity> _messages = [];
  final bool _isLoading = false;
  
  // Added caption variable to handle image captions without affecting the main controller
  String _caption = '';
  String get caption => _caption;

  ChatProvider({
    required this.getMessagesUseCase,
    required this.sendMessageUseCase,
  });

  List<MessageEntity> get messages => _messages;
  bool get isLoading => _isLoading;

  void setCaption(String value) {
    _caption = value;
    notifyListeners();
  }

  void clearCaption() {
    _caption = '';
    notifyListeners();
  }

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
