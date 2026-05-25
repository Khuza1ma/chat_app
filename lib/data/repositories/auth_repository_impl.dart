import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/firebase_auth_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthSource dataSource;

  AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, void>> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
  }) async {
    try {
      await dataSource.sendOTP(
        phoneNumber: phoneNumber,

        codeSent: (verificationId) {
          codeSent(verificationId);
        },

        verificationFailed: (e) {
          throw Exception(e.message);
        },
      );

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
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
}