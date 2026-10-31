import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/permission_labels.dart';

class UsersAccessScreen extends StatefulWidget {
  const UsersAccessScreen({super.key});

  @override
  State<UsersAccessScreen> createState() => _UsersAccessScreenState();
}

class _UsersAccessScreenState extends State<UsersAccessScreen> {
  String _userName = 'You';
  String? _userEmail;
  String? _ownerName;
  bool _isOwner = false;
  Map<String, dynamic>? _assistant;
  bool _loading = true;
  bool _savingPermissions = false;
  bool _openingInvite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _load();
  }

  Future<void> _load({Map<String, dynamic>? assistantFallback}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final name = await ApiService.getUserName();
      final email = await ApiService.getUserEmail();
      final profile = await ApiService.getCurrentUserProfile();
      final profileUser = profile['user'];
      final cachedOwner = await ApiService.isCurrentUserOwner();
      final isOwner = profileUser is Map
          ? ((profileUser['role'] is Map) &&
                profileUser['role']['name']?.toString().toLowerCase() ==
                    'owner')
          : cachedOwner;
      final access = isOwner
          ? await ApiService.getAssistantAccess()
          : <String, dynamic>{'success': true, 'assistant': null};

      if (!mounted) return;
      final assistant = access['assistant'];

      setState(() {
        _userName = name?.trim().isNotEmpty == true ? name!.trim() : 'You';
        _userEmail = email;
        _isOwner = isOwner;
        _ownerName = profileUser is Map
            ? _ownerNameFromUser(profileUser)
            : null;
        _assistant = assistant is Map
            ? Map<String, dynamic>.from(assistant)
            : assistantFallback;
        _loading = false;
        if (access['success'] != true) {
          _error =
              access['message']?.toString() ?? 'Could not load user access.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _assistant = assistantFallback ?? _assistant;
        _loading = false;
        _error = 'Could not load users and access: $error';
      });
    }
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

  String get _assistantLoginMessage =>
      'You are logged in as ${_ownerName?.isNotEmpty == true ? _ownerName : 'your account owner'}\'s assistant.';

  int? get _assistantId {
    final value = _assistant?['id'];
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  String get _assistantStatus =>
      _assistant?['status']?.toString().toLowerCase() ?? 'active';

  bool get _canEditPermissions =>
      !{'pending', 'invited', 'declined'}.contains(_assistantStatus);

  Set<String> get _assistantPermissions {
    final raw = _assistant?['permissions'];
    return raw is List
        ? raw.map((item) => item.toString()).toSet()
        : <String>{};
  }

  Future<void> _setPermission(String permission, bool enabled) async {
    final id = _assistantId;
    if (id == null || _savingPermissions || !_canEditPermissions) return;

    final previous = _assistantPermissions;
    final updated = _assistantPermissions;
    if (enabled) {
      updated.add(permission);
    } else {
      updated.remove(permission);
    }

    setState(() {
      _savingPermissions = true;
      _assistant = {...?_assistant, 'permissions': updated.toList()..sort()};
    });

    final result = await ApiService.updateAssistantPermissions(
      id,
      updated.toList()..sort(),
    );
    if (!mounted) return;
    setState(() {
      _savingPermissions = false;
      if (result['success'] != true) {
        _assistant = {...?_assistant, 'permissions': previous.toList()..sort()};
      }
    });
    if (result['success'] != true) {
      AppTheme.showTopSnackBar(
        context,
        result['message']?.toString() ?? 'Could not update permission.',
      );
    }
  }

  Future<void> _inviteUser() async {
    if (_openingInvite) return;
    setState(() => _openingInvite = true);
    final invited = await Navigator.pushNamed(context, '/invite-assistant');
    if (!mounted) return;
    setState(() => _openingInvite = false);
    await _load(
      assistantFallback: invited is Map
          ? Map<String, dynamic>.from(invited)
          : null,
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '' : DateFormat('d MMM yyyy').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Users & access'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            if (_error != null) ...[
              _ErrorNotice(message: _error!, onRetry: _load),
              const SizedBox(height: 14),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            _UserCard(
              name: _userName,
              subtitle: _userEmail ?? 'Email not available',
              initials: _initials(_userName),
              badge: _isOwner ? 'OWNER' : 'YOU',
              color: AppColors.orange,
            ),
            if (!_isOwner) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E6EF)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _assistantLoginMessage,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_assistant != null) ...[
              const SizedBox(height: 14),
              _assistantCard(),
            ],
            if (_isOwner) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openingInvite ? null : _inviteUser,
                icon: _openingInvite
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),
                label: Text(
                  _assistant == null
                      ? 'Invite an assistant'
                      : 'Invite another user',
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                  side: const BorderSide(color: Color(0xFFE0E6EF)),
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assistantCard() {
    final assistant = _assistant!;
    final name = assistant['name']?.toString().trim();
    final email = assistant['email']?.toString().trim();
    final joinedAt = _dateLabel(
      assistant['joined_at'] ?? assistant['created_at'],
    );
    final pending = !_canEditPermissions;
    final status = _assistantStatus;
    final subtitle = pending
        ? 'Invitation ${status == 'declined' ? 'declined' : 'pending'}'
        : joinedAt.isEmpty
        ? 'Assistant'
        : 'Assistant · joined $joinedAt';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: Column(
        children: [
          _UserIdentity(
            name: name?.isNotEmpty == true ? name! : 'Assistant',
            subtitle: email?.isNotEmpty == true ? email! : subtitle,
            initials: _initials(name?.isNotEmpty == true ? name! : 'Assistant'),
            badge: pending ? status.toUpperCase() : 'ASSISTANT',
            color: AppColors.teal,
          ),
          if (email?.isNotEmpty == true)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 59, bottom: 8),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
          const SizedBox(height: 4),
          for (var index = 0; index < availablePermissions.length; index++) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFE0E6EF)),
            _permissionRow(availablePermissions[index]),
          ],
          if (pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: Text(
                status == 'declined'
                    ? 'This invitation was declined. Invite a user again to restore access.'
                    : 'Permissions can be changed after the invitation is accepted.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _permissionRow(String permission) {
    final labels = <String, String>{
      'manage_appointments': 'Create, reschedule and cancel on your behalf',
      'record_outcomes': 'Capture discussions and meeting outcomes',
      'manage_action_points': 'Create and update follow-up actions',
      'export_reports': 'Generate and send PDF reports',
    };
    final enabled = _assistantPermissions.contains(permission);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permissionLabel(permission),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[permission] ?? 'Allow access to this feature',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeTrackColor: AppColors.green,
            onChanged: _savingPermissions || !_canEditPermissions
                ? null
                : (value) => _setPermission(permission, value),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.badge,
    required this.color,
  });

  final String name;
  final String subtitle;
  final String initials;
  final String badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0E6EF)),
      ),
      child: _UserIdentity(
        name: name,
        subtitle: subtitle,
        initials: initials,
        badge: badge,
        color: color,
      ),
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.badge,
    required this.color,
  });

  final String name;
  final String subtitle;
  final String initials;
  final String badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: color,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.red)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
