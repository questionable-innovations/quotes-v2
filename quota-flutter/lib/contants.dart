import 'package:flutter/material.dart';
import 'package:quota/api/client.dart';

final api = ApiClient();

extension ShowSnackBar on BuildContext {
  void showSnackBar({
    required String message,
    Color backgroundColor = Colors.white,
  }) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor,
    ));
  }

  void showErrorSnackBar({required String message}) {
    showSnackBar(message: message, backgroundColor: Colors.red);
  }
}

/// User-friendly message for API failures.
String errorMessage(Object error, String fallback) =>
    error is ApiException ? error.message : fallback;
