import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:provider/provider.dart';

import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/domain/entities/user.dart';
import 'package:chat_app/domain/repositories/auth_repository.dart';
import 'package:chat_app/main.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, String?>> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
  }) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    return Left(ServerFailure('Not implemented in test'));
  }

  @override
  Stream<UserEntity?> get onAuthStateChanged => Stream<UserEntity?>.value(null);

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('App boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_FakeAuthRepository()),
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Log in with Phone\nNumber'), findsOneWidget);
  });
}
