import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, String?>> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
  });

  Future<Either<Failure, UserEntity>> verifyOTP({
    required String verificationId,
    required String smsCode,
  });

  Stream<UserEntity?> get onAuthStateChanged;

  Future<void> signOut();
}