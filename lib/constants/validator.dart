String? emailValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter your email';
  }
  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email address';
  }
  return null;
}

String? passwordValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter Password';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

// Confirm Password Validator
String? confirmPasswordValidator(String? value, String? originalPassword) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != originalPassword) {
    return 'Passwords do not match';
  }
  return null;
}

String? validatePhoneNumber(String? value) {
  // Regular expression for validating international phone numbers
  // String pattern = r'^\+?([0-9]{1,3})?[-.●\s]?([0-9]{1,4})[-.●\s]?([0-9]{1,4})[-.●\s]?([0-9]{1,9})$';
  // RegExp regExp = RegExp(pattern);

  if (value == null || value.isEmpty) {
    return 'Please enter a phone number';
  }
  // else if (!regExp.hasMatch(value)) {
  //   return 'Please enter a valid phone number';
  // }
  return null;
}

//validation Name
String? nameValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Name is required';
  }

  return null;
}

//validation Name
String? messageValidator(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter your Message';
  }
  return null;
}
