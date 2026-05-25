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

  Future<bool> sendOTP(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _verificationId = null;
    notifyListeners();

    final result = await authRepository.sendOTP(
      phoneNumber: phoneNumber,

      codeSent: (verificationId) {
        _verificationId = verificationId;

        _status = AuthStatus.codeSent;
        notifyListeners();
      },
    );

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (verificationId) {
        if (verificationId != null && verificationId.isNotEmpty) {
          _verificationId = verificationId;
          _status = AuthStatus.codeSent;
        } else if (_user != null) {
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.initial;
        }
        notifyListeners();
        return true;
      },
    );
  }

  Future<bool> verifyOTP(String smsCode) async {
    if (_verificationId == null) {
      _status = AuthStatus.error;
      _errorMessage = 'Please request an OTP first.';
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(smsCode.trim())) {
      _status = AuthStatus.error;
      _errorMessage = 'Please enter the 6-digit OTP.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await authRepository.verifyOTP(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    return result.fold(
      (failure) {
        _status = AuthStatus.error;
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (user) {
        _user = user;
        _status = AuthStatus.authenticated;
        _verificationId = null;
        notifyListeners();
        return true;
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
