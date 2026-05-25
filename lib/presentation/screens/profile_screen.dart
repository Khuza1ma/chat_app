import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.primary,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              user?.displayName ?? 'No Name',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.phoneNumber ?? '',
              style: const TextStyle(fontSize: 16, color: AppColors.greyDark),
            ),
            const SizedBox(height: 40),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit Profile'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {},
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
