import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOTP(String phoneNumber);
  Future<Either<Failure, UserEntity>> verifyOTP(String verificationId, String smsCode);
  Stream<UserEntity?> get onAuthStateChanged;
  Future<void> signOut();
}
