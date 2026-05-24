import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../sources/firebase_auth_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthSource dataSource;

  AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, void>> sendOTP(String phoneNumber) async {
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> verifyOTP(String verificationId, String smsCode) async {
    throw UnimplementedError();
  }

  @override
  Stream<UserEntity?> get onAuthStateChanged {
    return dataSource.onAuthStateChanged.map((user) {
      if (user == null) return null;
      return UserEntity(uid: user.uid, phoneNumber: user.phoneNumber ?? '');
    });
  }

  @override
  Future<void> signOut() => dataSource.signOut();
}
