import 'package:flutter/material.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, codeSent, authenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;

  UserEntity? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  String? _verificationId;

  AuthProvider(this.authRepository) {
    authRepository.onAuthStateChanged.listen((user) {
      _user = user;
      if (user != null) {
        _status = AuthStatus.authenticated;
      } else {
        if (_status == AuthStatus.authenticated) {
          _status = AuthStatus.initial;
        }
      }
      notifyListeners();
    });
  }

  UserEntity? get user => _user;
  AuthStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> sendOTP(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await authRepository.sendOTP(phoneNumber);

    result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = "Failed to send OTP. Please check the number.";
        notifyListeners();
      },
      (_) {
        _status = AuthStatus.codeSent;
        _verificationId = "pending";
        notifyListeners();
      },
    );
  }

  Future<void> verifyOTP(String smsCode) async {
    if (_verificationId == null) return;

    _status = AuthStatus.loading;
    notifyListeners();

    final result = await authRepository.verifyOTP(_verificationId!, smsCode);

    result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = "Invalid OTP. Please try again.";
        notifyListeners();
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
      },
    );
  }

  void reset() {
    _status = AuthStatus.initial;
    _errorMessage = null;
    _verificationId = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await authRepository.signOut();
  }
}
