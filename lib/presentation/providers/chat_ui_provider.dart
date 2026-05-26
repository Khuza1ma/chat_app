import 'dart:io';

import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/presentation/screens/chat/models/chat_message_state.dart';
import 'package:flutter/material.dart';

class ChatUiProvider extends ChangeNotifier {
  List<MessageModel> _messages = [];
  List<ChatPendingMessage> _pendingMessages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  File? _pickedImage;
  String? _activeChatId;
  String? _currentUserId;
  Set<String> _selectedMessageIds = {};

  List<MessageModel> get messages => _messages;
  List<ChatPendingMessage> get pendingMessages => _pendingMessages;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  File? get pickedImage => _pickedImage;
  String? get activeChatId => _activeChatId;
  String? get currentUserId => _currentUserId;
  Set<String> get selectedMessageIds => _selectedMessageIds;
  bool get isSelectionMode => _selectedMessageIds.isNotEmpty;

  void setChatContext({required String currentUserId, required String chatId}) {
    _currentUserId = currentUserId;
    _activeChatId = chatId;
    notifyListeners();
  }

  void setMessages(List<MessageModel> value) {
    _messages = value;
    notifyListeners();
  }

  void addOlderMessages(List<MessageModel> olderMessages) {
    _messages = [..._messages, ...olderMessages];
    notifyListeners();
  }

  void setHasMore(bool value) {
    if (_hasMore == value) return;
    _hasMore = value;
    notifyListeners();
  }

  void setLoadingMore(bool value) {
    if (_isLoadingMore == value) return;
    _isLoadingMore = value;
    notifyListeners();
  }

  void setPickedImage(File? image) {
    _pickedImage = image;
    notifyListeners();
  }

  void addPendingMessage(ChatPendingMessage message) {
    _pendingMessages = [..._pendingMessages, message];
    notifyListeners();
  }

  void setPendingUploadedUrl({
    required String pendingId,
    required String? uploadedImageUrl,
  }) {
    final idx = _pendingMessages.indexWhere((p) => p.id == pendingId);
    if (idx == -1) return;
    final updated = _pendingMessages[idx].copyWith(
      uploadedImageUrl: uploadedImageUrl,
    );
    final next = List<ChatPendingMessage>.from(_pendingMessages);
    next[idx] = updated;
    _pendingMessages = next;
    notifyListeners();
  }

  void removePendingMessage(String pendingId) {
    _pendingMessages = _pendingMessages
        .where((p) => p.id != pendingId)
        .toList();
    notifyListeners();
  }

  void toggleSelection(String messageId) {
    final next = Set<String>.from(_selectedMessageIds);
    if (next.contains(messageId)) {
      next.remove(messageId);
    } else {
      next.add(messageId);
    }
    _selectedMessageIds = next;
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedMessageIds.isEmpty) return;
    _selectedMessageIds = {};
    notifyListeners();
  }

  void resetAfterSend() {
    _pickedImage = null;
    notifyListeners();
  }
}
