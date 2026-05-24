import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class VerifyOTPUseCase implements UseCase<UserEntity, VerifyOTPParams> {
  final AuthRepository repository;

  VerifyOTPUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(VerifyOTPParams params) {
    return repository.verifyOTP(params.verificationId, params.smsCode);
  }
}

class VerifyOTPParams {
  final String verificationId;
  final String smsCode;

  VerifyOTPParams({required this.verificationId, required this.smsCode});
}
