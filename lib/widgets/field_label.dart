import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small uppercase form-field label (e.g. "EMAIL ADDRESS"), with an
/// optional red asterisk for required fields.
class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const FieldLabel(this.text, {super.key, this.required = true});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Colors.grey[700],
        ),
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.red)),
        ],
      ),
    );
  }
}