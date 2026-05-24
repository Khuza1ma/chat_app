import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: 0,
              itemBuilder: (context, index) => const SizedBox(),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
