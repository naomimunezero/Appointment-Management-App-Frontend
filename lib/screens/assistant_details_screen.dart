import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/permission_labels.dart';

class AssistantDetailsScreen extends StatefulWidget {
  const AssistantDetailsScreen({super.key});

  @override
  State<AssistantDetailsScreen> createState() => _AssistantDetailsScreenState();
}

class _AssistantDetailsScreenState extends State<AssistantDetailsScreen> {
  Map<String, dynamic>? _assistant;
  Set<String> _permissions = {};
  bool _loading = true;
  bool _saving = false;
  bool _startedLoading = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_startedLoading) {
      _startedLoading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final result = await ApiService.getAssistantAccess();
    if (!mounted) return;
    final record = result['assistant'];
    setState(() {
      _loading = false;
      if (result['success'] == true && record is Map) {
        _assistant = Map<String, dynamic>.from(record);
        final raw = _assistant!['permissions'];
        _permissions = raw is List ? raw.map((p) => p.toString()).toSet() : {};
      } else if (result['success'] != true) {
        _error = result['message']?.toString();
      }
    });
  }

  int? get _inviteId {
    final id = _assistant?['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<void> _setPermission(String permission, bool enabled) async {
    final id = _inviteId;
    if (id == null || _saving || _isPending || _isDeclined) return;
    final updated = Set<String>.from(_permissions);
    if (enabled) {
      updated.add(permission); 
    } else {
      updated.remove(permission);
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ApiService.updateAssistantPermissions(id, updated.toList()..sort());
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result['success'] == true) {
        _permissions = updated;
      } else {
        _error = result['message']?.toString() ?? 'Unable to update permissions.';
      }
    });
  }

  bool get _isPending {
    final status = _assistant?['status']?.toString().toLowerCase();
    return status == 'pending' || status == 'invited';
  }

  bool get _isDeclined => _assistant?['status']?.toString().toLowerCase() == 'declined';

  Future<void> _inviteAnother() async {
    final result = await Navigator.pushNamed(context, '/invite-assistant');
    if (!mounted || result is! Map) return;
    setState(() {
      _assistant = Map<String, dynamic>.from(result);
      final raw = _assistant!['permissions'];
      _permissions = raw is List ? raw.map((item) => item.toString()).toSet() : {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _assistant?['name']?.toString();
    final email = _assistant?['email']?.toString() ?? 'Email not available';
    final rawStatus = _assistant?['status']?.toString().toLowerCase();
    final status = rawStatus?.isNotEmpty == true ? rawStatus! : 'pending';
    final pending = _isPending;
    final declined = _isDeclined;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Assistant details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _assistant == null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'No assistant invitation found.', textAlign: TextAlign.center),
                  ))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name?.isNotEmpty == true ? name! : 'Assistant', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
                          const SizedBox(height: 6),
                          Text(email, style: TextStyle(color: Colors.grey.shade700)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Icon(
                              pending ? Icons.schedule : declined ? Icons.cancel_outlined : Icons.verified_user_outlined,
                              size: 18,
                              color: pending ? AppColors.orange : declined ? AppColors.red : AppColors.green,
                            ),
                            const SizedBox(width: 7),
                            Expanded(child: Text(
                              pending
                                  ? 'Invitation to $email is still pending.'
                                  : declined
                                      ? 'The invitation to $email was declined.'
                                      : 'Invitation status: ${status[0].toUpperCase()}${status.substring(1)}',
                              style: TextStyle(
                                color: pending ? AppColors.orange : declined ? AppColors.red : AppColors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            )),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      const Text('PERMISSIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5, color: AppColors.navy)),
                      const SizedBox(height: 5),
                      Text(
                        _saving
                            ? 'Saving permission changes…'
                            : pending
                                ? 'Permissions can be changed after the invitation is accepted.'
                                : declined
                                    ? 'This invitation was declined, so permissions cannot be changed.'
                                    : 'Turn permissions on or off for this assistant.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(children: availablePermissions.map((permission) => SwitchListTile.adaptive(
                          value: _permissions.contains(permission),
                          onChanged: (_saving || pending || declined)
                              ? null
                              : (enabled) => _setPermission(permission, enabled),
                          activeColor: AppColors.green,
                          title: Text(permissionLabel(permission)),
                        )).toList()),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.red)),
                      ],
                      if (declined) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _inviteAnother,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Invite another assistant'),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}
