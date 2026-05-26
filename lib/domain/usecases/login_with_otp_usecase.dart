import 'package:dartz/dartz.dart';

import 'package:chat_app/core/error/failures.dart';
import 'package:chat_app/core/usecases/usecase.dart';
import 'package:chat_app/domain/entities/user.dart';
import 'package:chat_app/domain/repositories/auth_repository.dart';

class VerifyOTPUseCase implements UseCase<UserEntity, VerifyOTPParams> {
  final AuthRepository repository;

  VerifyOTPUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(VerifyOTPParams params) {
    return repository.verifyOTP(
      verificationId: params.verificationId,
      smsCode: params.smsCode,
    );
  }
}

class VerifyOTPParams {
  final String verificationId;
  final String smsCode;

  VerifyOTPParams({required this.verificationId, required this.smsCode});
}
