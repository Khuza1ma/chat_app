import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';
import 'package:chat_app/data/sources/firebase_chat_source.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final UserModel? otherUser;

  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseChatSource _chatSource = FirebaseChatSource();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;

  StreamSubscription<List<MessageModel>>? _subscription;
  List<MessageModel> _messages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  File? _pickedImage;

  String get _chatId {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final other = widget.otherUser;
    if (currentUser == null || other == null) return '';
    final ids = [currentUser.uid, other.uid]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // subscribe to messages stream after first frame to have context available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  void _startListening() {
    final id = _chatId;
    if (id.isEmpty) return;
    _subscription = _chatSource.getChatMessagesStream(id, _pageSize).listen((event) {
      // incoming stream is ordered descending (newest first)
      setState(() {
        // keep newest-first order
        _messages = event;
      });
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;
    // With reverse: true, when user scrolls to the bottom (older messages), position.pixels >= maxScrollExtent
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final last = _messages.last;
      final older = await _chatSource.getOlderChatMessages(_chatId, last.timestamp, _pageSize);
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        // Merge while avoiding duplicates (by id)
        final existingIds = _messages.map((m) => m.id).toSet();
        final toAdd = older.where((m) => !existingIds.contains(m.id)).toList();
        setState(() {
          _messages.addAll(toAdd);
        });
      }
    } catch (e) {
      // ignore
    }
    setState(() => _isLoadingMore = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  Future<void> _send() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    if (currentUser == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    String? uploadedUrl;
    if (_pickedImage != null) {
      try {
        uploadedUrl = await _chatSource.uploadImage(_pickedImage!);
      } catch (e) {
        // ignore upload errors for now
      }
    }

    final message = MessageModel(
      id: '',
      senderId: currentUser.uid,
      senderName: currentUser.displayName ?? currentUser.username ?? currentUser.phoneNumber,
      senderPhotoUrl: currentUser.profileUrl ?? currentUser.photoUrl,
      text: text,
      imageUrl: uploadedUrl,
      timestamp: DateTime.now(),
    );

    await _chatSource.sendChatMessage(_chatId, message);

    // update users lastMessage metadata for both participants (safe best-effort)
    try {
      final now = DateTime.now();
      final firestore = FirebaseFirestore.instance;
      final other = widget.otherUser;
      await firestore.collection('users').doc(currentUser.uid).update({
        'lastMessage': text.isNotEmpty ? text : (uploadedUrl != null ? 'Image' : ''),
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      });
      if (other != null) {
        await firestore.collection('users').doc(other.uid).update({
          'lastMessage': text.isNotEmpty ? text : (uploadedUrl != null ? 'Image' : ''),
          'lastMessageTime': Timestamp.fromDate(now),
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      // ignore update errors
    }

    _controller.clear();
    setState(() => _pickedImage = null);
    // Scroll to top (newest) after send
    await Future.delayed(const Duration(milliseconds: 200));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user;
    final other = widget.otherUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: other?.profileUrl != null ? NetworkImage(other!.profileUrl!) : null,
            child: other?.profileUrl == null ? Text((other?.displayName ?? other?.username ?? 'U').substring(0,1).toUpperCase()) : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(other?.displayName ?? other?.username ?? 'Chat')),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(currentUser?.uid ?? ''),
          ),
          const Divider(height: 1),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageList(String currentUid) {
    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final msg = _messages[index];
        final isMe = msg.senderId == currentUid;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              color: isMe ? Colors.blueAccent : Colors.grey[200],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe) Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (msg.imageUrl != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: msg.imageUrl!,
                          width: 240,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (msg.text.isNotEmpty) ...[
                      if (msg.imageUrl != null) const SizedBox(height: 6),
                      Text(msg.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(msg.timestamp),
                      style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][t.weekday-1];
    return '${t.month}/${t.day}/${t.year}';
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(onPressed: _pickImage, icon: const Icon(Icons.image)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Stack(
                        children: [
                          Image.file(_pickedImage!, width: 120, height: 80, fit: BoxFit.cover),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _pickedImage = null),
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,

                          decoration: const InputDecoration(
                            focusedBorder: InputBorder.none,
                            border: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            hint: Text('Type a message'),
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            fillColor: Colors.transparent,

                  )
                        ),
                      ),
                      IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
