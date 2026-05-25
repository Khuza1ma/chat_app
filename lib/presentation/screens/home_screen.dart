import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/data/models/user_model.dart';
import 'package:chat_app/data/sources/firebase_chat_source.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/presentation/screens/chat_screen.dart';
import 'package:chat_app/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseChatSource _chatSource = FirebaseChatSource();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  
  Stream<UserModel?>? _userStream;
  String? _lastUid;
  UserModel? _cachedUser; // Local cache to prevent UI flicker

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateUserStream(String? uid) {
    if (uid != _lastUid) {
      _lastUid = uid;
      _userStream = uid != null ? _chatSource.getUserStream(uid) : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final authUser = authProvider.user;
    
    _updateUserStream(authUser?.uid);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (authUser != null && _userStream != null)
            StreamBuilder<UserModel?>(
              stream: _userStream,
              initialData: _cachedUser,
              builder: (context, snapshot) {
                // Update local cache whenever new data arrives
                if (snapshot.hasData) {
                  _cachedUser = snapshot.data;
                }
                
                final user = snapshot.data;
                final profileUrl =
                    user?.profileUrl ??
                    user?.photoUrl ??
                    authUser.profileUrl ??
                    authUser.photoUrl;

                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Hero(
                    tag: 'profile_avatar',
                    child: GestureDetector(
                      onTap: () async {
                        _searchFocusNode.unfocus();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                        if (mounted) {
                          _searchFocusNode.unfocus();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.getColorFromString(
                            authUser.uid,
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: profileUrl ?? '',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => _searchFocusNode.unfocus(),
        child: Column(
          children: [
            _buildSearchField(),
            Expanded(
              child: StreamBuilder<List<UserModel>>(
                stream: _chatSource.getAllUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          const Text('Error loading conversations'),
                        ],
                      ),
                    );
                  }

                  final users =
                      (snapshot.data ?? [])
                          .where((u) => u.uid != authUser?.uid)
                          .where((u) {
                            final name = (u.displayName ?? u.username ?? '')
                                .toLowerCase();
                            return name.contains(_searchQuery.toLowerCase());
                          })
                          .toList();

                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.search_off_rounded,
                            size: 64,
                            color: AppColors.greyMedium.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No conversations yet'
                                : 'No matches found',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.greyDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userItem = users[index];
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(userItem.uid),
                        duration: Duration(
                          milliseconds: 300 + (index * 50).clamp(0, 300),
                        ),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildUserTile(context, userItem),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: false,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search chats...',
          hintStyle: const TextStyle(
            color: AppColors.greyDark,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.greyDark,
            size: 22,
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppColors.greyDark,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          filled: true,
          fillColor: AppColors.greyLight.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserModel user) {
    String formattedTime = '';
    if (user.lastMessageTime != null) {
      final now = DateTime.now();
      final difference = now.difference(user.lastMessageTime!);

      if (difference.inDays == 0) {
        formattedTime = DateFormat('HH:mm').format(user.lastMessageTime!);
      } else if (difference.inDays == 1) {
        formattedTime = 'Yesterday';
      } else if (difference.inDays < 7) {
        formattedTime = DateFormat('EEE').format(user.lastMessageTime!);
      } else {
        formattedTime = DateFormat('MMM dd').format(user.lastMessageTime!);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          _searchFocusNode.unfocus();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(otherUser: user),
            ),
          );
          if (mounted) {
            _searchFocusNode.unfocus();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Hero(
                tag: 'chat_avatar_${user.uid}',
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.getColorFromString(user.uid),
                        backgroundImage:
                            user.profileUrl != null
                                ? CachedNetworkImageProvider(user.profileUrl!)
                                : null,
                        child:
                            user.profileUrl == null
                                ? Text(
                                  (user.displayName ?? user.username ?? 'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                                : null,
                      ),
                    ),
                    if (user.isActive)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          user.displayName ?? user.username ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.lastMessage ?? 'Start a conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
