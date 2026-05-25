import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/domain/entities/user.dart';
import 'package:chat_app/domain/repositories/auth_repository.dart';
import 'package:chat_app/data/sources/firebase_auth_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthSource dataSource;

  AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, String?>> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
  }) async {
    try {
      final verificationId = await dataSource.sendOTP(
        phoneNumber: phoneNumber,

        codeSent: (verificationId) {
          codeSent(verificationId);
        },
      );

      return Right(verificationId);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e)));
    } catch (e) {
      return Left(ServerFailure('Unable to send OTP right now. Please try again.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final user = await dataSource.verifyOTP(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return Right(
        UserEntity(
          uid: user.uid,
          phoneNumber: user.phoneNumber ?? '',
        ),
      );
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapAuthError(e)));
    } catch (e) {
      return Left(ServerFailure('Unable to verify OTP right now. Please try again.'));
    }
  }

  @override
  Stream<UserEntity?> get onAuthStateChanged {
    return dataSource.onAuthStateChanged.map((user) {
      if (user == null) return null;

      return UserEntity(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
      );
    });
  }

  @override
  Future<void> signOut() async {
    await dataSource.signOut();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'missing-phone-number':
        return 'Please enter your phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'operation-not-allowed':
        return 'Phone authentication is disabled for this project.';
      case 'app-not-authorized':
        return 'This app is not authorized for phone authentication.';
      case 'captcha-check-failed':
      case 'captcha-check-failed-web':
      case 'recaptcha-check-failed':
        return 'Verification failed. Please try again.';
      case 'invalid-verification-code':
        return 'Incorrect OTP. Please enter the code sent to your phone.';
      case 'session-expired':
        return 'Your OTP has expired. Please request a new code.';
      case 'invalid-verification-id':
        return 'Your verification session expired. Please request a new OTP.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}