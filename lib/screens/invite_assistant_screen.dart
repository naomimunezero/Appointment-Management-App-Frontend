import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../utils/permission_labels.dart';

class InviteAssistantScreen extends StatefulWidget {
  const InviteAssistantScreen({super.key});

  @override
  State<InviteAssistantScreen> createState() => _InviteAssistantScreenState();
}

class _InviteAssistantScreenState extends State<InviteAssistantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  
  final Set<String> _selectedPermissions = <String>{};
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _error = null;
      _success = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPermissions.isEmpty) {
      setState(() => _error = 'Select at least one permission.');
      return;
    }

    final permissions = availablePermissions
        .where(_selectedPermissions.contains)
        .toList();

    setState(() => _loading = true);

    Map<String, dynamic> result;
    try {
      result = await ApiService.inviteAssistant(
        _emailController.text.trim(),
        permissions,
        name: _nameController.text.trim(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() => _success = 'Invitation sent successfully.');
      final invite = result['invite'];
      final createdInvite = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'permissions': permissions,
        'status': 'pending',
        if (invite is Map) ...Map<String, dynamic>.from(invite),
      };
      _emailController.clear();
      _selectedPermissions.clear();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context, createdInvite);
      });
    } else {
      setState(() => _error = result['message'] ?? 'Unable to send invite.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invite assistant'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.navy.withOpacity(0.12)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.navy),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Assistants can view and manage appointments when granted that permission. Other features require their own permission.',
                          style: TextStyle(fontSize: 14, color: AppColors.navy, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Assistant name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  enabled: !_loading,
                  decoration: const InputDecoration(hintText: 'Enter name.', hintStyle: TextStyle(color: Colors.grey, fontSize: 13)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Assistant email',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.navy),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    hintText: 'assistant@company.com',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  validator: emailValidator,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Permissions',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.navy),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: availablePermissions.map((permission) {
                      final selected = _selectedPermissions.contains(permission);
                      return SwitchListTile.adaptive(
                        value: selected,
                        onChanged: _loading ? null : (enabled) => setState(() {
                          if (enabled) {
                            _selectedPermissions.add(permission);
                          } else {
                            _selectedPermissions.remove(permission);
                          }
                        }),
                        activeColor: AppColors.green,
                        title: Text(permissionLabel(permission)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 28),
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AppColors.red)),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_success != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF9F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_success!, style: const TextStyle(color: AppColors.green)),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Send invite'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
