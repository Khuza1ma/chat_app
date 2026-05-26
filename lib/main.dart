import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chat_app/core/theme/app_theme.dart';
import 'package:chat_app/data/sources/firebase_auth_source.dart';
import 'package:chat_app/data/sources/firebase_chat_source.dart';
import 'package:chat_app/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/data/repositories/chat_repository_impl.dart';
import 'package:chat_app/core/router/app_router.dart';
import 'package:chat_app/domain/usecases/get_messages_usecase.dart';
import 'package:chat_app/domain/usecases/send_message_usecase.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/presentation/providers/chat_provider.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  final authDataSource = FirebaseAuthSource();
  final chatDataSource = FirebaseChatSource();
  final authRepository = AuthRepositoryImpl(authDataSource);
  final chatRepository = ChatRepositoryImpl(chatDataSource);
  final getMessagesUseCase = GetMessagesUseCase(chatRepository);
  final sendMessageUseCase = SendMessageUseCase(chatRepository);
  final authProvider = AuthProvider(authRepository);
  final chatProvider = ChatProvider(
    getMessagesUseCase: getMessagesUseCase,
    sendMessageUseCase: sendMessageUseCase,
  );
  final router = createAppRouter(authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: chatProvider),
      ],
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;

  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Chat App',
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
