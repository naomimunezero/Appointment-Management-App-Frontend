import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/field_label.dart';
import '../utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { email, code, newPassword }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _Step _step = _Step.email;

  // Each step gets its own form key + auto-validate flag so an error on
  // one step doesn't leak into the next once you move forward.
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _autoValidateEmail = false;
  bool _autoValidateCode = false;
  bool _autoValidatePassword = false;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _autoValidateEmail = true);
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.forgotPassword(_emailController.text.trim());

    setState(() => _loading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      setState(() => _step = _Step.code);
    } else {
      setState(() => _error = result['message']);
    }
  }

  void _confirmCode() {
    setState(() => _autoValidateCode = true);
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _step = _Step.newPassword;
    });
  }

  Future<void> _resetPassword() async {
    setState(() => _autoValidatePassword = true);
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _newPasswordController.text,
    );

    setState(() => _loading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      // Password reset — send them back to sign in with the new password.
      Navigator.pushNamed(context, '/login');
    } else {
      // Most likely an expired/incorrect code — send them back to re-enter it.
      setState(() {
        _error = result['message'];
        _step = _Step.code;
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.forgotPassword(_emailController.text.trim());
    setState(() => _loading = false);
    if (result['success'] != true) {
      setState(() => _error = result['message']);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code resent')),
      );
    }
  }

  void _goBack() {
    if (_step == _Step.code) {
      setState(() {
        _step = _Step.email;
        _error = null;
      });
    } else if (_step == _Step.newPassword) {
      setState(() {
        _step = _Step.code;
        _error = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              IconButton(
                onPressed: _loading ? null : _goBack,
                icon: const Icon(Icons.arrow_back, color: AppColors.navy),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.orange, width: 3),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2C5A94), AppColors.navy],
                      ),
                    ),
                    child: Icon(_stepIcon(), color: Colors.white, size: 34),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(_stepTitle(),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _stepSubtitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              const SizedBox(height: 30),
              if (_step == _Step.email) _buildEmailStep(),
              if (_step == _Step.code) _buildCodeStep(),
              if (_step == _Step.newPassword) _buildPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _stepIcon() {
    switch (_step) {
      case _Step.email:
        return Icons.mail_outline;
      case _Step.code:
        return Icons.pin_outlined;
      case _Step.newPassword:
        return Icons.lock_reset;
    }
  }

  String _stepTitle() {
    switch (_step) {
      case _Step.email:
        return 'Forgot password?';
      case _Step.code:
        return 'Enter the code';
      case _Step.newPassword:
        return 'Set new password';
    }
  }

  String _stepSubtitle() {
    switch (_step) {
      case _Step.email:
        return "Enter your email and we'll send you a reset code";
      case _Step.code:
        return 'We sent a code to ${_emailController.text.trim()}';
      case _Step.newPassword:
        return 'Choose a new password for your account';
    }
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      autovalidateMode: _autoValidateEmail ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('EMAIL ADDRESS'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'vincent@nugsoft.com',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            validator: emailValidator,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 24),
          _primaryButton(label: 'Send code', onPressed: _loading ? null : _sendCode),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      autovalidateMode: _autoValidateCode ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('RESET CODE'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: '123456',
              counterText: '',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Code is required';
              if (v.trim().length < 4) return 'Enter the full code';
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _loading ? null : _resendCode,
              child: const Text("Didn't get a code? Resend",
                  style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          _primaryButton(label: 'Verify code', onPressed: _loading ? null : _confirmCode),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      autovalidateMode: _autoValidatePassword ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('NEW PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[500], size: 20),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'New password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('CONFIRM PASSWORD'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey[500], size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _newPasswordController.text) return "Passwords don't match";
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 24),
          _primaryButton(label: 'Reset password', onPressed: _loading ? null : _resetPassword),
        ],
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          disabledBackgroundColor: AppColors.orange,
        ),
        child: _loading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

