import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/core/extension/toast_extension.dart';
import 'package:chat_app/core/router/app_paths.dart';
import 'package:chat_app/core/router/app_route_args.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/data/models/message_model.dart';
import 'package:chat_app/data/models/user_model.dart';
import 'package:chat_app/data/sources/firebase_chat_source.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/presentation/providers/chat_provider.dart';
import 'package:chat_app/presentation/providers/chat_ui_provider.dart';
import 'package:chat_app/presentation/screens/chat/models/chat_message_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

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
  final ChatUiProvider _uiProvider = ChatUiProvider();

  StreamSubscription<List<MessageModel>>? _subscription;

  String _buildChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChatContext();
    });
  }

  void _initializeChatContext() {
    if (!mounted) return;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final other = widget.otherUser;
    if (currentUser == null || other == null) return;

    _uiProvider.setChatContext(
      currentUserId: currentUser.uid,
      chatId: _buildChatId(currentUser.uid, other.uid),
    );
    _startListening();
  }

  void _startListening() {
    final id = _uiProvider.activeChatId;
    if (id == null || id.isEmpty) return;
    _subscription = _chatSource.getChatMessagesStream(id, _pageSize).listen((
      event,
    ) {
      if (!mounted) return;
      _uiProvider.setMessages(event);
    });
  }

  void _onScroll() {
    if (!_uiProvider.hasMore || _uiProvider.isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_uiProvider.messages.isEmpty || _uiProvider.activeChatId == null) {
      return;
    }
    _uiProvider.setLoadingMore(true);
    try {
      final last = _uiProvider.messages.last;
      final older = await _chatSource.getOlderChatMessages(
        _uiProvider.activeChatId!,
        last.timestamp,
        _pageSize,
      );
      if (older.isEmpty) {
        _uiProvider.setHasMore(false);
      } else {
        final existingIds = _uiProvider.messages.map((m) => m.id).toSet();
        final toAdd = older.where((m) => !existingIds.contains(m.id)).toList();
        if (!mounted) return;
        _uiProvider.addOlderMessages(toAdd);
      }
    } catch (e) {
      // ignore
    }
    if (!mounted) return;
    _uiProvider.setLoadingMore(false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _uiProvider.dispose();
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
              ctx.pop();
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pick from gallery'),
            onTap: () {
              ctx.pop();
              _pickImage(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 40,
      requestFullMetadata: false,
    );
    if (picked != null) {
      if (!mounted) return;
      final file = File(picked.path);
      final String? caption = await context.push<String?>(
        AppPaths.imagePreview,
        extra: ImagePreviewRouteArgs(
          file: file,
          initialCaption: _controller.text,
        ),
      );

      if (caption != null) {
        if (!mounted) return;
        // Use ChatProvider to handle the caption instead of direct controller assignment
        Provider.of<ChatProvider>(context, listen: false).setCaption(caption);
        _uiProvider.setPickedImage(file);
        await _send();
      }
    }
  }

  Future<void> _send() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final currentUser = auth.user;
    final other = widget.otherUser;
    if (currentUser == null || other == null) return;

    final String text = chatProvider.caption.isNotEmpty
        ? chatProvider.caption.trim()
        : _controller.text.trim();
    _controller.clear();

    if (text.isEmpty && _uiProvider.pickedImage == null) return;
    final chatId = _buildChatId(currentUser.uid, other.uid);
    final pendingId = DateTime.now().microsecondsSinceEpoch.toString();
    final localImage = _uiProvider.pickedImage;

    if (localImage != null) {
      _uiProvider.addPendingMessage(
        ChatPendingMessage(
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
    }

    String? uploadedUrl;
    if (localImage != null) {
      try {
        uploadedUrl = await _chatSource.uploadImage(localImage);
        if (mounted) {
          _uiProvider.setPendingUploadedUrl(
            pendingId: pendingId,
            uploadedImageUrl: uploadedUrl,
          );
        }
      } catch (e) {
        if (mounted) {
          _uiProvider.removePendingMessage(pendingId);
        }
        return;
      }
    }

    final message = MessageModel(
      isDeleted: false,
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
      _uiProvider.removePendingMessage(pendingId);
    }

    final lastMessagePreview = uploadedUrl != null ? 'Image' : text;

    try {
      final now = DateTime.now();
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(currentUser.uid).set({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      await firestore.collection('users').doc(other.uid).set({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore update errors
    }

    _controller.clear();
    chatProvider.clearCaption(); // Reset provider state after send

    if (!mounted) return;
    _uiProvider.resetAfterSend();
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

  void _toggleSelection(String messageId) {
    _uiProvider.toggleSelection(messageId);
  }

  void _clearSelection() {
    _uiProvider.clearSelection();
  }

  Future<void> _deleteSelectedMessages() async {
    if (_uiProvider.activeChatId == null ||
        _uiProvider.selectedMessageIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${_uiProvider.selectedMessageIds.length} messages?',
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final idsToDelete = List<String>.from(_uiProvider.selectedMessageIds);
      _clearSelection();
      try {
        for (final id in idsToDelete) {
          final isRemote = _uiProvider.messages.any((m) => m.id == id);
          if (isRemote) {
            await _chatSource.deleteChatMessage(_uiProvider.activeChatId!, id);
          } else {
            _uiProvider.removePendingMessage(id);
          }
        }
        if (mounted) {
          context.showToast(message: 'Messages deleted');
        }
      } catch (e) {
        if (mounted) {
          context.showToast(
            message: 'Failed to delete messages',
            type: ToastificationType.error,
          );
        }
      }
    }
  }

  void _copyToClipboard() {
    if (_uiProvider.selectedMessageIds.length != 1) return;
    final selectedId = _uiProvider.selectedMessageIds.first;
    final displayMessages = _buildDisplayMessages();
    final msg = displayMessages.firstWhere((m) => m.id == selectedId);

    if (msg.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: msg.text));
      _clearSelection();
    }
  }

  bool _canCopy() {
    if (_uiProvider.selectedMessageIds.length != 1) return false;
    final selectedId = _uiProvider.selectedMessageIds.first;
    final displayMessages = _buildDisplayMessages();
    try {
      final msg = displayMessages.firstWhere((m) => m.id == selectedId);
      // Disable if image is selected or if it's not a text message
      return msg.text.isNotEmpty &&
          msg.imageUrl == null &&
          msg.localImage == null;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.user;
    final other = widget.otherUser;
    return ChangeNotifierProvider<ChatUiProvider>.value(
      value: _uiProvider,
      child: Consumer<ChatUiProvider>(
        builder: (context, provider, child) {
          return PopScope(
            canPop: !provider.isSelectionMode,

            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && provider.isSelectionMode) {
                provider.clearSelection();
              }
            },
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child:
                    Selector<
                      ChatUiProvider,
                      ({bool isSelectionMode, int selectedCount})
                    >(
                      selector: (_, provider) => (
                        isSelectionMode: provider.isSelectionMode,
                        selectedCount: provider.selectedMessageIds.length,
                      ),
                      builder: (context, selectionState, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: selectionState.isSelectionMode
                            ? AppBar(
                                key: const ValueKey('selection_appbar'),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearSelection,
                                ),
                                title: Text(
                                  '${selectionState.selectedCount} messages selected...',
                                ),
                                actions: [
                                  if (_canCopy())
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: _copyToClipboard,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: _deleteSelectedMessages,
                                  ),
                                ],
                              )
                            : AppBar(
                                key: const ValueKey('normal_appbar'),
                                title: Row(
                                  children: [
                                    Hero(
                                      tag: 'chat_avatar_${other?.uid}',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.02,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: other != null
                                              ? AppColors.getColorFromString(
                                                  other.uid,
                                                )
                                              : AppColors.greyLight,
                                          backgroundImage:
                                              other?.profileUrl != null
                                              ? CachedNetworkImageProvider(
                                                  other!.profileUrl!,
                                                )
                                              : null,
                                          child: other?.profileUrl == null
                                              ? Text(
                                                  (other?.displayName ??
                                                          other?.username ??
                                                          'U')
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        other?.displayName ??
                                            other?.username ??
                                            'Chat',
                                      ),
                                    ),
                                  ],
                                ),
                                actions: const [],
                              ),
                      ),
                    ),
              ),
              body: Column(
                children: [
                  Expanded(child: _buildMessageList(currentUser?.uid ?? '')),
                  const Divider(height: 1),
                  Selector<ChatUiProvider, bool>(
                    selector: (_, provider) => provider.isSelectionMode,
                    builder: (context, isSelectionMode, _) => IgnorePointer(
                      ignoring: isSelectionMode,
                      child: _buildComposer(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(String fallbackCurrentUid) {
    return Selector<ChatUiProvider, _ChatListViewModel>(
      selector: (_, provider) => _ChatListViewModel(
        messages: provider.messages,
        pendingMessages: provider.pendingMessages,
        selectedMessageIds: provider.selectedMessageIds,
        isLoadingMore: provider.isLoadingMore,
        isSelectionMode: provider.isSelectionMode,
        currentUid: provider.currentUserId ?? fallbackCurrentUid,
      ),
      builder: (context, state, _) {
        final displayMessages = _buildDisplayMessagesFrom(
          state.messages,
          state.pendingMessages,
        );

        if (displayMessages.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: displayMessages.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (state.isLoadingMore && index == displayMessages.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final msg = displayMessages[index];
            final isMe = msg.senderId == state.currentUid;
            final isSelected = state.selectedMessageIds.contains(msg.id);
            final position = _getMessagePosition(displayMessages, index);

            return GestureDetector(
              onTap: state.isSelectionMode
                  ? () => _toggleSelection(msg.id)
                  : null,
              onLongPress: msg.isPending
                  ? null
                  : () => _toggleSelection(msg.id),
              child: Container(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: _buildMessageBubble(msg, isMe, position),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(
    ChatDisplayMessage msg,
    bool isMe,
    MessagePosition position,
  ) {
    final isImageOnly =
        (msg.localImage != null || msg.imageUrl != null) && msg.text.isEmpty;

    if (isImageOnly) {
      return Stack(
        children: [
          _buildMessageImage(msg, width: 240),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                msg.isPending ? 'Sending...' : _formatTimestamp(msg.timestamp),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Card(
        color: isMe ? Colors.blueAccent : Colors.grey[200],
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _messageBorderRadius(isMe, position),
        ),
        child: Padding(
          padding: msg.localImage != null || msg.imageUrl != null
              ? const EdgeInsets.only(bottom: 8)
              : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
    );
  }

  MessagePosition _getMessagePosition(
    List<ChatDisplayMessage> messages,
    int index,
  ) {
    final msg = messages[index];
    final hasSameSenderAbove =
        index > 0 && messages[index - 1].senderId == msg.senderId;
    final hasSameSenderBelow =
        index < messages.length - 1 &&
        messages[index + 1].senderId == msg.senderId;

    if (hasSameSenderAbove && hasSameSenderBelow) return MessagePosition.middle;
    if (hasSameSenderAbove) return MessagePosition.last;
    if (hasSameSenderBelow) return MessagePosition.first;
    return MessagePosition.isolated;
  }

  BorderRadius _messageBorderRadius(bool isMe, MessagePosition position) {
    const radius = 15.0;

    switch (position) {
      case MessagePosition.first:
        return isMe
            ? const BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              )
            : const BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              );
      case MessagePosition.middle:
        return isMe
            ? const BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
              )
            : const BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              );
      case MessagePosition.last:
        return isMe
            ? const BorderRadius.only(
                topLeft: Radius.circular(radius),
                bottomLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
              )
            : const BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
                topLeft: Radius.circular(radius),
              );
      case MessagePosition.isolated:
        return BorderRadius.circular(radius);
    }
  }

  Widget _buildMessageImage(ChatDisplayMessage msg, {required double width}) {
    if (msg.localImage != null) {
      final heroTag = 'message_image_${msg.id}';
      return GestureDetector(
        onTap: () {
          if (_uiProvider.isSelectionMode) {
            _toggleSelection(msg.id);
            return;
          }

          context.push(
            AppPaths.imageViewer,
            extra: ImageViewerRouteArgs(file: msg.localImage, heroTag: heroTag),
          );
        },
        child: Hero(
          tag: heroTag,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.grey, width: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                msg.localImage!,
                width: width,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }

    final heroTag = 'message_image_${msg.id}';
    return GestureDetector(
      onTap: () {
        if (_uiProvider.isSelectionMode) {
          _toggleSelection(msg.id);
          return;
        }

        context.push(
          AppPaths.imageViewer,
          extra: ImageViewerRouteArgs(imageUrl: msg.imageUrl, heroTag: heroTag),
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: Colors.grey, width: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: msg.imageUrl!,
              width: width,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.grey, width: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.image, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }

  List<ChatDisplayMessage> _buildDisplayMessages() {
    return _buildDisplayMessagesFrom(
      _uiProvider.messages,
      _uiProvider.pendingMessages,
    );
  }

  List<ChatDisplayMessage> _buildDisplayMessagesFrom(
    List<MessageModel> remoteMessages,
    List<ChatPendingMessage> pendingMessages,
  ) {
    final remote = remoteMessages.map(ChatDisplayMessage.fromRemote).toList();
    final pending = pendingMessages
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
        .map(ChatDisplayMessage.fromPending)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _showAttachmentOptions,
            icon: const Icon(Icons.attachment),
          ),
          Expanded(
            child: Row(
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
                      hintText: 'Type a message',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    final isNotEmpty = value.text.trim().isNotEmpty;
                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isNotEmpty ? 1.0 : 0.5,
                      child: IconButton(
                        onPressed: isNotEmpty ? _send : null,
                        icon: const Icon(Icons.send),
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListViewModel {
  final List<MessageModel> messages;
  final List<ChatPendingMessage> pendingMessages;
  final Set<String> selectedMessageIds;
  final bool isLoadingMore;
  final bool isSelectionMode;
  final String currentUid;

  const _ChatListViewModel({
    required this.messages,
    required this.pendingMessages,
    required this.selectedMessageIds,
    required this.isLoadingMore,
    required this.isSelectionMode,
    required this.currentUid,
  });

  @override
  bool operator ==(Object other) {
    return other is _ChatListViewModel &&
        identical(messages, other.messages) &&
        identical(pendingMessages, other.pendingMessages) &&
        identical(selectedMessageIds, other.selectedMessageIds) &&
        isLoadingMore == other.isLoadingMore &&
        isSelectionMode == other.isSelectionMode &&
        currentUid == other.currentUid;
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(messages),
    identityHashCode(pendingMessages),
    identityHashCode(selectedMessageIds),
    isLoadingMore,
    isSelectionMode,
    currentUid,
  );
}
