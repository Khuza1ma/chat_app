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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final chatSource = FirebaseChatSource();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.background,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: IconButton(
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage:
                      user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null
                      ? const Icon(Icons.person, size: 20, color: Colors.white)
                      : null,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: chatSource.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Error loading messages: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.greyDark),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading messages',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline, size: 64, color: AppColors.greyMedium),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.greyDark,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a new conversation',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.greyDark,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userItem = users[index];
              return _buildUserTile(context, userItem);
            },
          );
        },
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
        onTap: () {
          print('User tapped: ${user.profileUrl}');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen(otherUser: user)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _getColorFromString(user.uid),
                    backgroundImage: user.profileUrl != null
                        ? CachedNetworkImageProvider(user.profileUrl!)
                        : null,
                    child: user.profileUrl == null
                        ? Text(
                            (user.displayName ?? user.username ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  if (user.isActive)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName ?? user.username ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.greyDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.lastMessage ?? 'No messages yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.greyDark,
                        fontWeight: user.lastMessage != null
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Color _getColorFromString(String str) {
    final colors = [
      const Color(0xFF377DFE),
      const Color(0xFF03DAC6),
      const Color(0xFFFF6B6B),
      const Color(0xFFFFA500),
      const Color(0xFF9C27B0),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
    ];
    return colors[str.hashCode % colors.length];
  }
}
