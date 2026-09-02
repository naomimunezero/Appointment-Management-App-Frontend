import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/field_label.dart';
import '../utils/validators.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _autoValidate = false;
  String? _error;

  Future<void> _signIn() async {
    // Errors only appear from this point on — first tap turns on live
    // validation, so retyping a field updates its error immediately.
    setState(() => _autoValidate = true);

    // Gate: run field validators (required email + password) before hitting the API
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.login(_emailController.text.trim(), _passwordController.text);
    setState(() => _loading = false);
    if (result['success'] == true) {
      if (!mounted) return;

      final pendingInvites = result['pendingInvites'];
      if (pendingInvites is List && pendingInvites.isNotEmpty) {
        Navigator.pushReplacementNamed(
          context,
          '/pending-invite',
          arguments: {'invite': pendingInvites.first},
        );
        return;
      }

      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } else {
      setState(() => _error = result['message']);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidate ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Container(
                    width: 110,
                    height: 110,
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
                      child: const Icon(Icons.event_available, color: Colors.white, size: 38),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text('Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.navy)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Sign in to manage your appointments', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ),
                const SizedBox(height: 36),
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
                const SizedBox(height: 20),
                const FieldLabel('PASSWORD'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[500], size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                    child: const Text('Forgot password?', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.red)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    // Always tappable (except while loading) — tapping while
                    // fields are empty runs the Form validator, which surfaces
                    // "Email is required" / "Password is required" under each field.
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        children: const [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(text: 'Register', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

