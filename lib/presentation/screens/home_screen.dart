import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/presentation/screens/profile_screen.dart';
import 'package:chat_app/presentation/screens/chat_screen.dart';
import 'package:chat_app/core/theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
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
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome, ${user?.phoneNumber ?? 'User'}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Go to Chats'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
