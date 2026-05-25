import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

extension ToastExtension on BuildContext {
  void showToast({
    required String message,
    ToastificationType type = ToastificationType.success,
    String? title,
    Duration? autoCloseDuration,
  }) {
    toastification.show(
      context: this,
      type: type,
      style: ToastificationStyle.flat,
      title: title != null ? Text(title) : null,
      description: Text(message),
      alignment: Alignment.bottomCenter,
      autoCloseDuration: autoCloseDuration ?? const Duration(seconds: 4),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 16,
          offset: Offset(0, 16),
        ),
      ],
      showProgressBar: false,
    );
  }
}
