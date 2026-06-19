import 'package:flutter/foundation.dart';

class ErrorHandler {
  /// Logs the raw error and stack trace to the debug console
  /// and returns a user-friendly error message for the UI.
  static String handle(dynamic error, [StackTrace? stackTrace]) {
    // 1. Print raw error and stack trace to the debug console
    if (kDebugMode) {
      print('=================== DEBUG ERROR LOG ===================');
      print('RAW ERROR: $error');
      if (stackTrace != null) {
        print('STACK TRACE:\n$stackTrace');
      } else if (error is Error && error.stackTrace != null) {
        print('STACK TRACE:\n${error.stackTrace}');
      }
      print('=======================================================');
    }

    // 2. Determine a user-understandable, clean error message
    final errorString = error.toString().toLowerCase();

    // Check for network/connectivity errors
    if (errorString.contains('socketexception') ||
        errorString.contains('connectionerror') ||
        errorString.contains('network') ||
        errorString.contains('handshake') ||
        errorString.contains('failed to connect') ||
        errorString.contains('unreachable')) {
      return 'Internet connection issue. Please check your network and try again.';
    }

    // Check for timeout errors
    if (errorString.contains('timeout') ||
        errorString.contains('time out') ||
        errorString.contains('connection timeout') ||
        errorString.contains('receive timeout') ||
        errorString.contains('send timeout')) {
      return 'Connection timed out. The server is taking too long to respond. Please try again.';
    }

    // Check for authorization/session errors
    if (errorString.contains('401') ||
        errorString.contains('unauthorized') ||
        errorString.contains('jwt') ||
        errorString.contains('token expired') ||
        errorString.contains('session expired')) {
      return 'Session expired. Please log in again to continue.';
    }

    // Check for permission errors
    if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }

    // Check for not found errors
    if (errorString.contains('404') || errorString.contains('not found')) {
      return 'Requested resource not found. Please try again later.';
    }

    // Check for server/internal errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error') ||
        errorString.contains('server error')) {
      return 'Our servers are experiencing issues. Please try again in a few moments.';
    }

    // Check for insufficient balance errors
    if (errorString.contains('insufficient') ||
        errorString.contains('balance')) {
      return 'Insufficient wallet balance. Please add money to continue.';
    }

    // Check for auth/registration error variations
    if (errorString.contains('already registered') ||
        errorString.contains('already exists') ||
        errorString.contains('phone number already registered') ||
        errorString.contains('credential-already-in-use') ||
        errorString.contains('email-already-in-use')) {
      return 'This phone number is already registered. Please log in instead.';
    }

    if (errorString.contains('not registered') ||
        errorString.contains('user-not-found')) {
      return 'This phone number is not registered. Please sign up first.';
    }

    if (errorString.contains('invalid-verification-code') ||
        errorString.contains('invalid otp') ||
        errorString.contains('wrong otp') ||
        errorString.contains('sms-code-expired') ||
        errorString.contains('session-expired') ||
        errorString.contains('sms code has expired')) {
      return 'Invalid or expired OTP. Please check the code and try again.';
    }

    if (errorString.contains('too-many-requests') ||
        errorString.contains('quota exceeded') ||
        errorString.contains('blocked')) {
      return 'Too many attempts. Please wait a few minutes before trying again.';
    }

    // Game/contest specific errors
    if (errorString.contains('joined') ||
        errorString.contains('already joined')) {
      return 'You have already joined this contest.';
    }

    if (errorString.contains('contest ended') ||
        errorString.contains('contest has ended')) {
      return 'This contest has already ended.';
    }

    if (errorString.contains('invalid pan')) {
      return 'Please enter a valid 10-digit PAN card number.';
    }

    if (errorString.contains('invalid account') ||
        errorString.contains('ifsc')) {
      return 'Please enter a valid Bank Account Number and IFSC code.';
    }

    // Clean any generic exception prefix if present
    String cleaned = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Exception', '')
        .replaceAll('DioException', '')
        .trim();

    // Strip bracketed headers (e.g. "[bad response]", "[connection error]") and leading colons
    cleaned = cleaned.replaceAll(RegExp(r'^\[.*?\]\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^:\s*'), '').trim();

    final lowercaseCleaned = cleaned.toLowerCase();

    // Check if the cleaned message looks like a raw system traceback or internal error
    if (cleaned.isEmpty ||
        lowercaseCleaned.contains('traceback') ||
        lowercaseCleaned.contains('unboundlocal') ||
        lowercaseCleaned.contains('file "') ||
        lowercaseCleaned.contains('line ') ||
        lowercaseCleaned.contains('syntaxerror') ||
        lowercaseCleaned.contains('operationalerror') ||
        lowercaseCleaned.contains('programmingerror') ||
        lowercaseCleaned.contains('database') ||
        lowercaseCleaned.contains('internalservererror') ||
        lowercaseCleaned.contains('500') ||
        lowercaseCleaned.contains('bad response') ||
        lowercaseCleaned == 'null' ||
        lowercaseCleaned.contains('unknown connection error')) {
      return 'An unexpected server error occurred. Please try again later.';
    }

    return cleaned;
  }
}
