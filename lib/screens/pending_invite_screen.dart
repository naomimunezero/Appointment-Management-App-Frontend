import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/permission_labels.dart';

class PendingInviteScreen extends StatefulWidget {
  const PendingInviteScreen({super.key});

  @override
  State<PendingInviteScreen> createState() => _PendingInviteScreenState();
}

class _PendingInviteScreenState extends State<PendingInviteScreen> {
  bool _loading = false;
  String? _error;

  Map<String, dynamic> _invite(Map<String, dynamic>? arguments) {
    if (arguments == null) {
      return {};
    }
    if (arguments['invite'] is Map<String, dynamic>) {
      return arguments['invite'] as Map<String, dynamic>;
    }
    if (arguments['invite'] is Map) {
      return Map<String, dynamic>.from(arguments['invite'] as Map);
    }
    return arguments;
  }

  String _ownerName(Map<String, dynamic> invite) {
    final owner = invite['owner'];
    if (owner is Map) {
      final value = owner['name'] ?? owner['full_name'] ?? owner['email'];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    return invite['owner_name'] ?? invite['name'] ?? 'Owner';
  }

  String _ownerEmail(Map<String, dynamic> invite) {
    final owner = invite['owner'];
    if (owner is Map) {
      final value = owner['email'];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    final fallbackEmail = invite['owner_email'] ?? invite['ownerEmail'];
    if (fallbackEmail != null && fallbackEmail.toString().isNotEmpty) {
      return fallbackEmail.toString();
    }

    return 'owner@example.com';
  }

  String _inviterHeader(Map<String, dynamic> invite) {
    final email = _ownerEmail(invite);
    if (email.isNotEmpty && email != 'owner@example.com') {
      return 'You were invited by $email';
    }
    return 'You have a pending assistant invite from';
  }

  List<String> _permissions(Map<String, dynamic> invite) {
    final permissions = invite['permissions'];
    if (permissions is List) {
      return permissions.map((value) => value.toString()).toList();
    }
    return const [];
  }

  // CHANGED: was _token() reading invite['token']; now reads the invite's id
  int? _inviteId(Map<String, dynamic> invite) {
    final id = invite['id'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  Future<void> _accept(Map<String, dynamic> invite) async {
    final inviteId = _inviteId(invite); // CHANGED
    if (inviteId == null) {
      setState(() => _error = 'Missing invite id.'); // CHANGED message
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.acceptAssistantInvite(inviteId: inviteId); // CHANGED
    setState(() => _loading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() => _error = result['message'] ?? 'Could not accept invitation.');
    }
  }

  Future<void> _decline(Map<String, dynamic> invite) async {
    final inviteId = _inviteId(invite); // CHANGED
    if (inviteId == null) {
      setState(() => _error = 'Missing invite id.'); // CHANGED message
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.declineAssistantInvite(inviteId: inviteId); // CHANGED
    setState(() => _loading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      setState(() => _error = result['message'] ?? 'Could not decline invitation.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? const {};
    final invite = _invite(args);
    final permissions = _permissions(invite);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assistant invite'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                _inviterHeader(invite),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              Text(
                _ownerEmail(invite),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),
              const Text(
                'Permissions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.navy),
              ),
              const SizedBox(height: 12),
              if (permissions.isEmpty)
                const Text('No permissions listed.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: permissions.map((permission) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        permissionLabel(permission),
                        style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700),
                      ),
                    );
                  }).toList(),
                ),
              const Spacer(),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _decline(invite),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.red),
                        foregroundColor: AppColors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : () => _accept(invite),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}