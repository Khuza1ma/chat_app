import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';
import 'package:chat_app/data/sources/firebase_chat_source.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<_PendingMessage> _pendingMessages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  File? _pickedImage;
  String? _activeChatId;
  String? _currentUserId;

  String _buildChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Resolve current user once context is available, then start stream.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChatContext();
    });
  }

  void _initializeChatContext() {
    if (!mounted) return;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final other = widget.otherUser;
    if (currentUser == null || other == null) return;

    _currentUserId = currentUser.uid;
    _activeChatId = _buildChatId(currentUser.uid, other.uid);
    _startListening();
  }

  void _startListening() {
    final id = _activeChatId;
    if (id == null || id.isEmpty) return;
    _subscription = _chatSource.getChatMessagesStream(id, _pageSize).listen((
      event,
    ) {
      if (!mounted) return;
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty || _activeChatId == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final last = _messages.last;
      final older = await _chatSource.getOlderChatMessages(
        _activeChatId!,
        last.timestamp,
        _pageSize,
      );
      if (older.isEmpty) {
        _hasMore = false;
      } else {
        // Merge while avoiding duplicates (by id)
        final existingIds = _messages.map((m) => m.id).toSet();
        final toAdd = older.where((m) => !existingIds.contains(m.id)).toList();
        if (!mounted) return;
        setState(() {
          _messages.addAll(toAdd);
        });
      }
    } catch (e) {
      // ignore
    }
    if (!mounted) return;
    setState(() => _isLoadingMore = false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Capture from camera'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pick from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1600);
    if (picked != null) {
      if (!mounted) return;
      final file = File(picked.path);
      final String? caption = await showDialog<String?>(
        context: context,
        builder: (_) =>
            _ImagePreviewDialog(file: file, initialCaption: _controller.text),
      );

      if (caption != null) {
        if (!mounted) return;
        _controller.text = caption;
        setState(() => _pickedImage = file);
        await _send();
      }
    }
  }

  Future<void> _send() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    final other = widget.otherUser;
    if (currentUser == null || other == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;
    final chatId = _buildChatId(currentUser.uid, other.uid);
    final pendingId = DateTime.now().microsecondsSinceEpoch.toString();
    final localImage = _pickedImage;

    if (localImage != null) {
      setState(() {
        _pendingMessages.add(
          _PendingMessage(
            id: pendingId,
            senderId: currentUser.uid,
            senderName:
                currentUser.displayName ??
                currentUser.username ??
                currentUser.phoneNumber,
            text: text,
            localImage: localImage,
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    String? uploadedUrl;
    if (localImage != null) {
      try {
        uploadedUrl = await _chatSource.uploadImage(localImage);
        if (mounted) {
          setState(() {
            final idx = _pendingMessages.indexWhere((p) => p.id == pendingId);
            if (idx != -1) {
              _pendingMessages[idx] = _pendingMessages[idx].copyWith(
                uploadedImageUrl: uploadedUrl,
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _pendingMessages.removeWhere((p) => p.id == pendingId);
          });
        }
        return;
      }
    }

    final message = MessageModel(
      id: '',
      senderId: currentUser.uid,
      senderName:
          currentUser.displayName ??
          currentUser.username ??
          currentUser.phoneNumber,
      senderPhotoUrl: currentUser.profileUrl ?? currentUser.photoUrl,
      text: text,
      imageUrl: uploadedUrl,
      timestamp: DateTime.now(),
    );

    await _chatSource.sendChatMessage(chatId, message);

    if (mounted && localImage != null) {
      setState(() {
        _pendingMessages.removeWhere((p) => p.id == pendingId);
      });
    }

    // update users lastMessage metadata for both participants (safe best-effort)
    try {
      final now = DateTime.now();
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(currentUser.uid).update({
        'lastMessage': text.isNotEmpty
            ? text
            : (uploadedUrl != null ? 'Image' : ''),
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      });
      await firestore.collection('users').doc(other.uid).update({
        'lastMessage': text.isNotEmpty
            ? text
            : (uploadedUrl != null ? 'Image' : ''),
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      // ignore update errors
    }

    _controller.clear();
    if (!mounted) return;
    setState(() => _pickedImage = null);
    // Scroll to top (newest) after send
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user;
    final other = widget.otherUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: other?.profileUrl != null
                  ? NetworkImage(other!.profileUrl!)
                  : null,
              child: other?.profileUrl == null
                  ? Text(
                      (other?.displayName ?? other?.username ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(other?.displayName ?? other?.username ?? 'Chat'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(_currentUserId ?? currentUser?.uid ?? ''),
          ),
          const Divider(height: 1),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageList(String currentUid) {
    final displayMessages = _buildDisplayMessages();

    if (displayMessages.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: displayMessages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoadingMore && index == displayMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final msg = displayMessages[index];
        final isMe = msg.senderId == currentUid;
        final isImageOnly =
            (msg.localImage != null || msg.imageUrl != null) &&
            msg.text.isEmpty;

        if (isImageOnly) {
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Stack(
                children: [
                  _buildMessageImage(msg, width: 240),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg.isPending
                            ? 'Sending...'
                            : _formatTimestamp(msg.timestamp),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Card(
              color: isMe ? Colors.blueAccent : Colors.grey[200],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: msg.localImage != null || msg.imageUrl != null
                    ? const EdgeInsets.only(bottom: 8)
                    : const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        msg.senderName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (msg.localImage != null || msg.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildMessageImage(msg, width: 240),
                      ),
                    ],
                    if (msg.text.isNotEmpty) ...[
                      if (msg.localImage != null || msg.imageUrl != null)
                        const SizedBox(height: 6),
                      Padding(
                        padding: msg.localImage != null || msg.imageUrl != null
                            ? const EdgeInsets.symmetric(horizontal: 8)
                            : EdgeInsets.zero,
                        child: Text(
                          msg.text,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Padding(
                      padding: msg.localImage != null || msg.imageUrl != null
                          ? const EdgeInsets.symmetric(horizontal: 8)
                          : EdgeInsets.zero,
                      child: Text(
                        msg.isPending
                            ? 'Sending...'
                            : _formatTimestamp(msg.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
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

  Widget _buildMessageImage(_DisplayMessage msg, {required double width}) {
    if (msg.localImage != null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Image.file(msg.localImage!, width: width, fit: BoxFit.cover),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: msg.imageUrl!,
          width: width,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  List<_DisplayMessage> _buildDisplayMessages() {
    final remote = _messages.map(_DisplayMessage.fromRemote).toList();
    final pending = _pendingMessages
        .where((pendingMsg) {
          if (pendingMsg.uploadedImageUrl == null) {
            return true;
          }

          return !remote.any((remoteMsg) {
            return remoteMsg.senderId == pendingMsg.senderId &&
                remoteMsg.text == pendingMsg.text &&
                remoteMsg.imageUrl == pendingMsg.uploadedImageUrl;
          });
        })
        .map(_DisplayMessage.fromPending)
        .toList();

    return [...remote, ...pending]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday - 1];
    }
    return '${t.month}/${t.day}/${t.year}';
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: _showAttachmentOptions,
              icon: const Icon(Icons.attachment),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          ),
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

class _PendingMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final File localImage;
  final DateTime timestamp;
  final String? uploadedImageUrl;

  const _PendingMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.localImage,
    required this.timestamp,
    this.uploadedImageUrl,
  });

  _PendingMessage copyWith({String? uploadedImageUrl}) {
    return _PendingMessage(
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

class _DisplayMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String? imageUrl;
  final File? localImage;
  final DateTime timestamp;
  final bool isPending;

  const _DisplayMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.imageUrl,
    required this.localImage,
    required this.timestamp,
    required this.isPending,
  });

  factory _DisplayMessage.fromRemote(MessageModel message) {
    return _DisplayMessage(
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

  factory _DisplayMessage.fromPending(_PendingMessage message) {
    return _DisplayMessage(
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

class _ImagePreviewDialog extends StatefulWidget {
  final File file;
  final String initialCaption;

  const _ImagePreviewDialog({required this.file, required this.initialCaption});

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  late final TextEditingController _captionController;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: size.width * 0.95,
        height: size.height * 0.75,
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Image.file(widget.file, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _captionController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add a caption...'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Discard',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(_captionController.text.trim()),
                      child: const Text('Send'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
