import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _canManageAppointments = false;
  bool _canExportReports = false;
  Map<String, dynamic>? _assistantAccess;
  List<int> _defaultReminders = [];
  bool _loadingReminders = true;
  bool _savingReminders = false;
  bool _loadingNotificationSettings = true;
  final Set<String> _savingNotificationSettings = <String>{};
  final Map<String, dynamic> _notificationSettings = {
    'daily_summary': true,
    'overdue_alerts': true,
    'assistant_activity_alerts': true,
    'missed_nudge': false,
    'daily_summary_time': '06:30',
  };

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _loadPermissions();
    _loadAssistantAccess();
    _loadReminderDefaults();
    _loadNotificationSettings();
  }

  bool _settingEnabled(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  Future<void> _loadNotificationSettings() async {
    final result = await ApiService.getNotificationSettings();
    if (!mounted) return;
    setState(() {
      _loadingNotificationSettings = false;
      if (result['success'] == true && result['settings'] is Map) {
        final values = Map<String, dynamic>.from(result['settings'] as Map);
        for (final key in [
          'daily_summary',
          'overdue_alerts',
          'assistant_activity_alerts',
          'missed_nudge',
        ]) {
          if (values.containsKey(key)) {
            _notificationSettings[key] = _settingEnabled(
              values[key],
              fallback: _notificationSettings[key] as bool,
            );
          }
        }
        final time = values['daily_summary_time']?.toString();
        if (time != null && RegExp(r'^\d{2}:\d{2}').hasMatch(time)) {
          _notificationSettings['daily_summary_time'] = time.substring(0, 5);
        }
      }
    });
    if (result['success'] != true) {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Could not load notification settings',
      );
    }
  }

  Future<void> _updateNotificationSetting(
    String key,
    bool value,
    String label,
  ) async {
    if (_loadingNotificationSettings ||
        _savingNotificationSettings.contains(key))
      return;
    final previous = _notificationSettings[key] as bool;
    setState(() {
      _notificationSettings[key] = value;
      _savingNotificationSettings.add(key);
    });
    final result = await ApiService.updateNotificationSettings({key: value});
    if (!mounted) return;
    setState(() {
      _savingNotificationSettings.remove(key);
      if (result['success'] != true) _notificationSettings[key] = previous;
    });
    AppTheme.showTopSnackBar(
      context,
      result['success'] == true
          ? '$label ${value ? 'enabled' : 'disabled'}'
          : (result['message'] ?? 'Could not update $label'),
    );
  }

  Future<TimeOfDay?> _showTimePicker() async {
    final currentTime = _notificationSettings['daily_summary_time'] as String;
    final parts = currentTime.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 6;
    final initialMinute = int.tryParse(parts[1]) ?? 30;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.navy),
          ),
          child: child!,
        );
      },
    );

    return selectedTime;
  }

  Future<void> _updateDailySummaryTime(TimeOfDay time) async {
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final previous = _notificationSettings['daily_summary_time'] as String;
    setState(() {
      _notificationSettings['daily_summary_time'] = timeString;
      _savingNotificationSettings.add('daily_summary_time');
    });

    final result = await ApiService.updateNotificationSettings({
      'daily_summary_time': timeString,
    });

    if (!mounted) return;
    setState(() {
      _savingNotificationSettings.remove('daily_summary_time');
      if (result['success'] != true) {
        _notificationSettings['daily_summary_time'] = previous;
      }
    });

    if (result['success'] != true) {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Could not update daily summary time',
      );
    }
  }

  String get _dailySummaryTimeLabel {
    final time = _notificationSettings['daily_summary_time'] as String;
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return time;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _loadReminderDefaults() async {
    final result = await ApiService.getReminderDefaults();
    if (!mounted) return;
    setState(() {
      _loadingReminders = false;
      if (result['success'] == true) {
        _defaultReminders = (result['reminders'] as List)
            .map<int>((item) => (item['minutes_before'] as num).toInt())
            .toList();
      }
    });
    if (result['success'] != true) {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Could not load default reminders',
      );
    }
  }

  Future<int?> _editReminder({int? minutes}) async {
    final navigator = Navigator.of(context);
    final route = DialogRoute<int>(
      context: context,
      builder: (_) => _ReminderEditorDialog(initialMinutes: minutes),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    );
    final value = await navigator.push(route);
    await route.completed;
    return value;
  }

  String _reminderLabel(int minutes) {
    if (minutes % 1440 == 0)
      return '${minutes ~/ 1440} ${minutes ~/ 1440 == 1 ? 'day' : 'days'} before';
    if (minutes % 60 == 0)
      return '${minutes ~/ 60} ${minutes ~/ 60 == 1 ? 'hr' : 'hrs'} before';
    return '$minutes min before';
  }

  Future<void> _persistReminderDefaults(
    List<int> updatedReminders, {
    required String successMessage,
  }) async {
    final previousReminders = List<int>.from(_defaultReminders);
    setState(() {
      _defaultReminders = updatedReminders;
      _savingReminders = true;
    });

    final result = await ApiService.saveReminderDefaults(
      updatedReminders
          .map((minutes) => <String, dynamic>{'minutes_before': minutes})
          .toList(),
    );
    if (!mounted) return;
    setState(() {
      _savingReminders = false;
      if (result['success'] != true) _defaultReminders = previousReminders;
    });
    AppTheme.showTopSnackBar(
      context,
      result['success'] == true
          ? successMessage
          : (result['message'] ?? 'Could not save default reminders'),
    );
  }

  Future<void> _editDefaultReminder(int index) async {
    if (_savingReminders) return;
    final value = await _editReminder(minutes: _defaultReminders[index]);
    if (value == null || !mounted || _savingReminders) return;
    final updated = List<int>.from(_defaultReminders)..[index] = value;
    await _persistReminderDefaults(
      updated,
      successMessage: 'Default reminder updated',
    );
  }

  Future<void> _removeDefaultReminder(int index) async {
    if (_savingReminders) return;
    final updated = List<int>.from(_defaultReminders)..removeAt(index);
    await _persistReminderDefaults(
      updated,
      successMessage: 'Default reminder removed',
    );
  }

  Future<void> _addDefaultReminder() async {
    if (_savingReminders) return;
    final value = await _editReminder();
    if (value == null || !mounted || _savingReminders) return;
    await _persistReminderDefaults([
      ..._defaultReminders,
      value,
    ], successMessage: 'Default reminder added');
  }

  Future<void> _loadAssistantAccess() async {
    final result = await ApiService.getAssistantAccess();
    if (!mounted) return;
    if (result['success'] != true) return;
    final assistant = result['assistant'];
    setState(
      () => _assistantAccess = assistant is Map
          ? Map<String, dynamic>.from(assistant)
          : null,
    );
  }

  Future<void> _loadPermissions() async {
    final permissions = await Future.wait([
      ApiService.hasPermission('manage_appointments'),
      ApiService.hasPermission('export_reports'),
    ]);
    if (!mounted) return;
    setState(() {
      _canManageAppointments = permissions[0];
      _canExportReports = permissions[1];
    });
  }

  Future<void> _logout(BuildContext context) async {
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
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  children: [
                    _defaultRemindersCard(),
                    const SizedBox(height: 18),
                    _toggleSection(_assistantAccess != null),
                    const SizedBox(height: 18),
                    _profileRow(context),
                    const SizedBox(height: 18),
                    _accessSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 2 && _canExportReports)
            Navigator.pushNamed(context, '/reports');
          if (index == 3) return;
        },
        onAddTap: _canManageAppointments
            ? () => Navigator.pushNamed(context, '/new-appointment')
            : null,
        showReports: _canExportReports,
      ),
    );
  }

  Widget _defaultRemindersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEFAULT REMINDERS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingReminders)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _defaultReminders.length; i++)
                  InputChip(
                    label: Text(_reminderLabel(_defaultReminders[i])),
                    onPressed: _savingReminders
                        ? null
                        : () => _editDefaultReminder(i),
                    onDeleted: _savingReminders
                        ? null
                        : () => _removeDefaultReminder(i),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                    labelStyle: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_defaultReminders.length < 10)
                  ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      color: AppColors.orange,
                      size: 18,
                    ),
                    label: const Text('Add reminder'),
                    onPressed: _savingReminders ? null : _addDefaultReminder,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Applied to every new appointment; can be changed per appointment.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _toggleSection(bool hasAssistant) {
    final rows = <Widget>[
      _toggleRow(
        'Daily Appointments summary',
        'Your day at a glance, $_dailySummaryTimeLabel',
        'daily_summary',
        'Daily Appointments summary',
        showTimePicker: true,
      ),
      const Divider(height: 20),
      _toggleRow(
        'Overdue action alerts',
        'Notify when a follow-up passes its due date',
        'overdue_alerts',
        'Overdue action alerts',
      ),
    ];

    if (hasAssistant) {
      rows.add(const Divider(height: 20));
      rows.add(
        _toggleRow(
          'Assistant activity alerts',
          'When assistant adds or changes an appointment',
          'assistant_activity_alerts',
          'Assistant activity alerts',
        ),
      );
    }

    rows.add(const Divider(height: 20));
    rows.add(
      _toggleRow(
        'Missed-appointment nudge',
        'Prompt to record or reschedule after end time',
        'missed_nudge',
        'Missed-appointment nudge',
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _toggleRow(
    String title,
    String subtitle,
    String settingKey,
    String label, {
    bool showTimePicker = false,
  }) {
    final enabled = _notificationSettings[settingKey] as bool;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled,
          activeColor: AppColors.green,
          onChanged:
              _loadingNotificationSettings ||
                  _savingNotificationSettings.contains(settingKey)
              ? null
              : (value) async {
                  if (showTimePicker && value) {
                    // Show time picker before enabling
                    final selectedTime = await _showTimePicker();
                    if (selectedTime != null) {
                      // Update the time setting first
                      await _updateDailySummaryTime(selectedTime);
                      // Then enable the setting
                      _updateNotificationSetting(settingKey, value, label);
                    }
                    // If user cancelled time picker, don't enable the setting
                  } else {
                    _updateNotificationSetting(settingKey, value, label);
                  }
                },
        ),
      ],
    );
  }

  Widget _profileRow(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, '/profile'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile & password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your personal details and security',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 28, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _accessSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => Navigator.pushNamed(context, '/users-access'),
        title: const Text(
          'Users & access',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        subtitle: const Text('Manage users and their permissions'),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({this.initialMinutes});

  final int? initialMinutes;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  late final TextEditingController _controller;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final minutes = widget.initialMinutes;
    _controller = TextEditingController(
      text: minutes == null
          ? ''
          : '${minutes % 60 == 0 ? minutes ~/ 60 : minutes}',
    );
    _unit = minutes != null && minutes % 60 == 0 ? 'hr' : 'min';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1) {
      AppTheme.showTopSnackBar(context, 'Enter a number greater than zero');
      return;
    }
    final multiplier = _unit == 'day'
        ? 1440
        : _unit == 'hr'
        ? 60
        : 1;
    Navigator.of(context).pop(value * multiplier);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialMinutes == null
            ? 'Add default reminder'
            : 'Edit default reminder',
      ),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Remind me'),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _unit,
            items: const [
              DropdownMenuItem(value: 'min', child: Text('min')),
              DropdownMenuItem(value: 'hr', child: Text('hr')),
              DropdownMenuItem(value: 'day', child: Text('day')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _unit = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
