import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import 'forgot_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'You';
  String? _email;
  bool _isOwner = false;
  String? _ownerName;
  Map<String, dynamic>? _assistant;
  bool _loading = true;
  bool _loadingTeam = true;
  bool _savingProfile = false;
  String? _error;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadingTeam = true;
      _error = null;
    });
    final result = await ApiService.getCurrentUserProfile();
    if (!mounted) return;
    final user = result['user'];
    setState(() {
      if (result['success'] == true && user is Map) {
        final role = user['role'];
        _name = user['name']?.toString().trim().isNotEmpty == true
            ? user['name'].toString().trim()
            : 'You';
        _email = user['email']?.toString();
        _isOwner =
            role is Map && role['name']?.toString().toLowerCase() == 'owner';
        _ownerName = _ownerNameFromUser(user);
      } else {
        _error =
            result['message']?.toString() ?? 'Could not load your profile.';
      }
      _loading = false;
    });

    if (!_isOwner) {
      setState(() {
        _assistant = null;
        _loadingTeam = false;
      });
      return;
    }

    final assistantResult = await ApiService.getAssistantAccess();
    if (!mounted) return;
    final rawAssistant = assistantResult['assistant'];
    setState(() {
      _assistant = rawAssistant is Map
          ? Map<String, dynamic>.from(rawAssistant)
          : null;
      _loadingTeam = false;
      if (assistantResult['success'] != true) {
        _error ??=
            assistantResult['message']?.toString() ??
            'Could not load team details.';
      }
    });
  }

  String get _initials {
    final words = _name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String _assistantLabel() {
    final name =
        _assistant?['name'] ?? _assistant?['full_name'] ?? _assistant?['email'];
    return name?.toString().trim().isNotEmpty == true
        ? name.toString()
        : 'No assistant added yet';
  }

  String? _ownerNameFromUser(Map user) {
    final owner = user['owner'];
    if (owner is Map) {
      for (final key in ['name', 'full_name', 'email']) {
        final value = owner[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    for (final key in ['owner_name', 'owner_full_name', 'owner_email']) {
      final value = user[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(
      text: _name == 'You' ? '' : _name,
    );
    final emailController = TextEditingController(text: _email ?? '');
    final formKey = GlobalKey<FormState>();

    // CHANGED: plain showDialog instead of DialogRoute + navigator.push
    final profile = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: emailValidator,
              ),
              const SizedBox(height: 8),
              Text(
                'Changing your email will require a verification code.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // CHANGED: dispose after the dialog's exit animation has finished
    Future.delayed(const Duration(milliseconds: 400), () {
      nameController.dispose();
      emailController.dispose();
    });

    if (profile == null || !mounted) return;

    final newName = profile['name'];
    final newEmail = profile['email'];

    // Check if email is being changed
    if (newEmail != null && newEmail.isNotEmpty && newEmail != _email) {
      await _initiateEmailChange(newName, newEmail);
    } else if (newName != null && newName.isNotEmpty && newName != _name) {
      // Only name is changing, no password needed
      setState(() => _savingProfile = true);
      final result = await ApiService.updateProfile(name: newName);
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        if (result['success'] == true && result['user'] is Map) {
          final user = result['user'] as Map;
          _name = user['name']?.toString() ?? _name;
        }
      });
      AppTheme.showTopSnackBar(
        context,
        result['success'] == true
            ? 'Profile updated successfully.'
            : result['message']?.toString() ?? 'Could not update your profile.',
      );
    }
  } // CHANGED: this closing brace was missing

  Future<void> _initiateEmailChange(String? newName, String newEmail) async {
    // Step 1: Request verification code
    setState(() => _savingProfile = true);
    try {
      final result = await ApiService.requestEmailChange(newEmail);
      if (!mounted) return;
      setState(() => _savingProfile = false);

      if (result['success'] != true) {
        AppTheme.showTopSnackBar(
          context,
          result['message'] ?? 'Could not send verification code',
        );
        return;
      }

      // Step 2: Show verification code input dialog (no password)
      final codeController = TextEditingController();
      bool obscureCode = true;
      String? codeError;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Verify email change'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter the 6-digit code sent to your current email'),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  obscureText: obscureCode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Verification code',
                    hintText: '123456',
                    errorText: codeError,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCode ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureCode = !obscureCode);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final code = codeController.text.trim();
                  if (code.isEmpty || code.length != 6) {
                    setDialogState(() => codeError = 'Enter 6-digit code');
                  } else {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      );

      // Store code value before disposing controller
      final code = codeController.text.trim();
      codeController.dispose();

      if (confirmed != true || !mounted) return;

      // Step 3: Confirm email change with code only (no password)
      setState(() => _savingProfile = true);
      try {
        final result = await ApiService.confirmEmailChange(
          email: newEmail,
          code: code,
        );

        if (!mounted) return;
        setState(() => _savingProfile = false);

        if (result['success'] == true && result['user'] is Map) {
          final user = result['user'] as Map;
          setState(() {
            _name = user['name']?.toString() ?? _name;
            _email = user['email']?.toString() ?? _email;
          });
          // Reload profile data to ensure fresh state
          await _loadProfile();
          AppTheme.showTopSnackBar(context, 'Email changed successfully.');
        } else {
          AppTheme.showTopSnackBar(
            context,
            result['message'] ?? 'Could not confirm email change',
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _savingProfile = false);
        AppTheme.showTopSnackBar(context, 'Could not confirm email change: $e');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingProfile = false);
      AppTheme.showTopSnackBar(context, 'Could not send verification code: $e');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    await ApiService.clearToken();
    if (!mounted) return;
    AppTheme.showTopSnackBar(
      context,
      'You are logged out. Please login again to continue.',
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My profile'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            _profileHeader(),
            const SizedBox(height: 16),
            if (_error != null) ...[_errorNotice(), const SizedBox(height: 16)],
            _sectionCard(
              title: 'PERSONAL DETAILS',
              action: TextButton.icon(
                onPressed: _loading || _savingProfile ? null : _editProfile,
                icon: _savingProfile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined, size: 17),
                label: Text(_savingProfile ? 'Saving' : 'Edit'),
                style: TextButton.styleFrom(foregroundColor: AppColors.navy),
              ),
              children: [
                _detailRow(Icons.person_outline, 'Name', _name),
                const Divider(height: 22),
                _detailRow(
                  Icons.mail_outline,
                  'Email',
                  _email ?? 'Email not available',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _teamCard(),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'SECURITY',
              children: [
                _actionRow(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  subtitle: 'We’ll email you a secure password reset link',
                  onTap: _email == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ForgotPasswordScreen(initialEmail: _email!),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _signingOut ? null : _signOut,
                icon: _signingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_signingOut ? 'Signing out...' : 'Sign out'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.orange,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.navy, width: 2),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 14,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _email ?? 'Email not available',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isOwner ? 'OWNER' : 'ASSISTANT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamCard() {
    final assistantStatus = _assistant?['status']?.toString();
    return _sectionCard(
      title: _isOwner ? 'MY ASSISTANTS' : 'WORKING WITH',
      children: [
        _actionRow(
          icon: Icons.people_outline,
          title: _isOwner ? _assistantLabel() : _assistantLoginLabel(),
          subtitle: _loadingTeam
              ? 'Loading team details...'
              : _isOwner
              ? (assistantStatus?.isNotEmpty == true
                    ? assistantStatus!
                    : 'Manage appointment access')
              : 'Your appointment account owner',
          onTap: _isOwner
              ? () => Navigator.pushNamed(context, '/users-access')
              : null,
        ),
      ],
    );
  }

  String _ownerLabel() {
    if (_ownerName?.isNotEmpty == true) return _ownerName!;
    final owner = _assistant?['owner'];
    if (owner is Map) {
      final label = owner['name'] ?? owner['full_name'] ?? owner['email'];
      if (label?.toString().trim().isNotEmpty == true) {
        return label.toString();
      }
    }
    final label = _assistant?['owner_name'] ?? _assistant?['owner_email'];
    return label?.toString().trim().isNotEmpty == true
        ? label.toString()
        : 'Account owner';
  }

  String _assistantLoginLabel() =>
      'You are logged in as ${_ownerLabel()}\'s assistant';

  Widget _errorNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: const TextStyle(color: AppColors.navy)),
          ),
          TextButton(onPressed: _loadProfile, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              ?action,
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.navy.withValues(alpha: 0.65)),
        const SizedBox(width: 12),
        SizedBox(
          width: 62,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.orange, size: 21),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.navy),
      onTap: onTap,
    );
  }
}
