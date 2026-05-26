import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:toastification/toastification.dart';
import 'package:chat_app/presentation/providers/auth_provider.dart';
import 'package:chat_app/core/extension/toast_extension.dart';
import 'package:chat_app/core/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String? _validatePhoneNumber(String phone) {
    if (phone.isEmpty) {
      return 'Please enter your phone number.';
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Please enter a valid 10-digit phone number.';
    }

    return null;
  }

  String? _validateOtp(String otp) {
    if (otp.isEmpty) {
      return 'Please enter the OTP sent to your phone.';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return 'Please enter the 6-digit OTP.';
    }

    return null;
  }

  void _showAuthError(String message) {
    if (!mounted) return;

    context.showToast(
      message: message,
      type: ToastificationType.error,
      title: 'Authentication error',
    );
  }

  Future<void> _submitPhone(AuthProvider authProvider) async {
    final phone = _phoneController.text.trim();
    final validationMessage = _validatePhoneNumber(phone);

    if (validationMessage != null) {
      _showAuthError(validationMessage);
      return;
    }

    final success = await authProvider.sendOTP('+91$phone');

    if (!success && authProvider.errorMessage != null) {
      _showAuthError(authProvider.errorMessage!);
    }
  }

  Future<void> _submitOtp(AuthProvider authProvider, String otp) async {
    final validationMessage = _validateOtp(otp.trim());

    if (validationMessage != null) {
      _showAuthError(validationMessage);
      return;
    }

    final success = await authProvider.verifyOTP(otp.trim());

    if (!success && authProvider.errorMessage != null) {
      _showAuthError(authProvider.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 70,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildCurrentView(authProvider),
              ),
              if (authProvider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView(AuthProvider authProvider) {
    if (authProvider.status == AuthStatus.initial ||
        (authProvider.status == AuthStatus.error &&
            authProvider.verificationId == null) ||
        (authProvider.status == AuthStatus.loading &&
            authProvider.verificationId == null)) {
      return _buildPhoneInput(authProvider, key: const ValueKey('phoneInput'));
    } else {
      return _buildOTPInput(authProvider, key: const ValueKey('otpInput'));
    }
  }

  Widget _buildPhoneInput(AuthProvider authProvider, {required Key key}) {
    return Column(
      key: key,
      children: [
        const Text(
          'Log in with Phone\nNumber',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          readOnly:
          authProvider.status == AuthStatus.loading ||
              authProvider.status == AuthStatus.codeSent,
          style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
          decoration: InputDecoration(
            hintText: '9898121245',
            hintStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
            prefixIcon:  Padding(
              padding: const EdgeInsets.only(left: 16, right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1.5,
                    height: 24,
                    color: Colors.black,
                  ),
                ],
              ),
            ),

            counterText: '',
            filled: true,
            fillColor: Colors.white,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),

            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: authProvider.isLoading
                ? null
                : () => _submitPhone(authProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Log in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPInput(AuthProvider authProvider, {required Key key}) {
    return Column(
      key: key,
      children: [
        const Text(
          'Verify Phone',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Code sent to +91 ${_phoneController.text}',
          style: const TextStyle(color: AppColors.greyDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Pinput(
          length: 6,
          controller: _otpController,
          onCompleted: (pin) => _submitOtp(authProvider, pin),
          defaultPinTheme: PinTheme(
            width: 50,
            height: 56,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.greyLight,
              border: Border.all(color: Colors.transparent),
            ),
          ),
          focusedPinTheme: PinTheme(
            width: 50,
            height: 56,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.greyLight,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (authProvider.isLoading)
          const CircularProgressIndicator()
        else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _submitOtp(authProvider, _otpController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Verify & Log in',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _otpController.clear();
              authProvider.reset();
            },
            child: const Text(
              'Change phone number?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

