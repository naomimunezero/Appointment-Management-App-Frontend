/// Shared form-validation helpers.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

/// Ready-to-use validator for TextFormField(validator: ...).
String? emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  if (!isValidEmail(value)) return 'Enter a valid email';
  return null;
}

/// Ready-to-use validator for a plain required field, e.g.
/// requiredValidator('Full name') -> "Full name is required".
String? Function(String?) requiredValidator(String label) {
  return (value) => (value == null || value.trim().isEmpty) ? '$label is required' : null;
}