import 'package:video/core/utils/extensions.dart';

class ValidationHelper {
  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.isValidEmail) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validate strong password
  static String? validateStrongPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (!value.isStrongPassword) {
      return 'Password must contain uppercase, lowercase, and numbers';
    }
    return null;
  }

  /// Validate username
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, underscores, and dashes';
    }
    return null;
  }

  /// Validate required field
  static String? validateRequired(
    String? value, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate minimum characters
  static String? validateMinCharacters(
    String? value,
    int min, [
    String fieldName = 'This field',
  ]) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < min) {
      return '$fieldName must be at least $min characters';
    }
    return null;
  }

  /// Validate maximum characters
  static String? validateMaxCharacters(
    String? value,
    int max, [
    String fieldName = 'This field',
  ]) {
    if (value == null) return null;
    if (value.length > max) {
      return '$fieldName must not exceed $max characters';
    }
    return null;
  }
}
