import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/action_point.dart';
import '../services/api_service.dart';
import '../widgets/appointment_info_section.dart';
import '../widgets/meeting_with_section.dart';
import '../widgets/reminders_section.dart';
import '../widgets/history_section.dart';
import '../widgets/action_buttons_section.dart';
import '../widgets/discussion_notes_and_action_points_section.dart';
import '../utils/date_time_utils.dart';

class AppointmentDetailsScreen extends StatefulWidget {
  final int appointmentId;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  State<AppointmentDetailsScreen> createState() => _AppointmentDetailsScreenState();
}


class _AppointmentDetailsScreenState extends State<AppointmentDetailsScreen> {
  late Future<Appointment> _appointmentFuture;
  List<dynamic> _history = [];
  bool _canManageAppointments = false;
  bool _canRecordOutcomes = false;
  bool _canManageActionPoints = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
    _loadPermissions();
    _loadHistory();
  }

  Future<void> _loadPermissions() async {
    final values = await Future.wait([
      ApiService.hasPermission('manage_appointments'),
      ApiService.hasPermission('record_outcomes'),
      ApiService.hasPermission('manage_action_points'),
    ]);
    if (!mounted) return;
    setState(() {
      _canManageAppointments = values[0];
      _canRecordOutcomes = values[1];
      _canManageActionPoints = values[2];
    });
  }

  Future<void> _editActionPoint(ActionPoint actionPoint) async {
    final descriptionController = TextEditingController(text: actionPoint.description);
    final ownerController = TextEditingController(
      text: actionPoint.responsiblePerson ?? actionPoint.owner ?? '',
    );
    DateTime? dueDate = actionPoint.dueDate;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit action point'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: ownerController,
                  decoration: const InputDecoration(labelText: 'Responsible person'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dueDate == null ? 'No due date' : DateFormat.yMMMd().format(dueDate!)),
                ),
                if (dueDate != null)
                  TextButton(
                    onPressed: () => setDialogState(() => dueDate = null),
                    child: const Text('Clear due date'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'description': descriptionController.text.trim(),
                'owner': ownerController.text.trim(),
                'dueDate': dueDate,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    descriptionController.dispose();
    ownerController.dispose();
    if (values == null || (values['description'] as String).isEmpty || !mounted) return;
    final selectedDate = values['dueDate'] as DateTime?;
    final result = await ApiService.updateActionPoint(
      actionPoint.id,
      values['description'] as String,
      (values['owner'] as String).isEmpty ? null : values['owner'] as String,
      selectedDate?.toIso8601String().substring(0, 10),
    );
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId));
    } else {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Could not edit action point',
        appBarHeight: kToolbarHeight + kTextTabBarHeight,
      );
    }
  }

  Future<void> _deleteActionPoint(ActionPoint actionPoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete action point'),
        content: const Text('Are you sure you want to delete this action point?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ApiService.deleteActionPoint(actionPoint.id);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId));
    } else {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Could not delete action point',
        appBarHeight: kToolbarHeight + kTextTabBarHeight,
      );
    }
  }

  void _loadAppointmentAndDebug() async {
    final appointment = await _appointmentFuture;
    print('Appointment Details Debug:');
    print('  Status: ${appointment.status}');
    print('  Held At: ${appointment.heldAt}');
    print('  Discussion Notes: ${appointment.discussionNotes}');
    print('  Action Points Count: ${appointment.actionPoints.length}');
    for (var ap in appointment.actionPoints) {
      print('    - ${ap.description} (completed: ${ap.completed})');
    }
  }
  Future<void> _loadHistory() async {
    final data = await ApiService.getAppointmentHistory(widget.appointmentId);
    if (mounted) setState(() => _history = data);
  }

  Future<void> _recordOutcome() async {
    final result = await Navigator.pushNamed(
      context,
      '/record-outcome',
      arguments: {'appointmentId': widget.appointmentId},
    );

    // If outcome was recorded, refresh the appointment details
    if (result == true) {
      setState(() {
        _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
      });
      _loadHistory(); // Refresh history as well
    }
  }

  Future<void> _editAppointment() async {
    final updated = await Navigator.pushNamed(
      context,
      '/new-appointment',
      arguments: {'editAppointmentId': widget.appointmentId},
    );
    if (updated is Appointment && mounted) {
      // PUT returns the complete updated appointment. Keep that exact response
      // so new/removed reminders are visible without waiting for another GET.
      setState(() {
        _appointmentFuture = Future.value(updated);
      });
      _loadHistory();
    } else if (updated == true && mounted) {
      // Retain a safe fallback for an older or non-standard API response.
      setState(() {
        _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
      });
      _loadHistory();
    }
  }

  Future<void> _rescheduleAppointment(Appointment appointment) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAppointmentSheet(appointment: appointment),
    );

    if (updated == true && mounted) {
      setState(() {
        _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
      });
      _loadHistory(); // Refresh history as well
    }
  }

  bool _isHeldAppointment(Appointment appointment) {
    return appointment.status.toLowerCase() == 'held';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Appointment'),
        centerTitle: true,
        bottom: const TabBar(
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Details'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: FutureBuilder<Appointment>(
        future: _appointmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading appointment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
                      });
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No appointment data'),
            );
          }

          final appointment = snapshot.data!;

          return TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppointmentInfoSection(appointment: appointment),
                    const SizedBox(height: 16),
                    MeetingWithSection(
                      attendees: appointment.attendees,
                      sectionTitle: 'MEETING WITH',
                    ),
                    const SizedBox(height: 16),
                    if (!_isHeldAppointment(appointment) &&
                        (_canRecordOutcomes || _canManageAppointments))
                      ActionButtonsSection(
                        onRecordOutcome: _canRecordOutcomes ? _recordOutcome : null,
                        onEdit: _canManageAppointments ? _editAppointment : null,
                        onReschedule: _canManageAppointments ? () => _rescheduleAppointment(appointment) : null,
                      ),
                    if (_isHeldAppointment(appointment))
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'This appointment has been marked as held',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (appointment.heldAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Recorded on ${_formatHeldAt(appointment.heldAt!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Show discussion notes and action points for held appointments
                    if (_isHeldAppointment(appointment))
                      DiscussionNotesAndActionPointsSection(
                        discussionNotes: appointment.discussionNotes,
                        actionPoints: appointment.actionPoints,
                        markDoneOnly: true,
                        showToggle: _canManageActionPoints,
                        onActionPointToggle: _canManageActionPoints ? (index, completed) async {
                          try {
                            final actionPoint = appointment.actionPoints[index];
                            final result = await ApiService.updateActionPointStatus(
                              actionPoint.id,
                              completed,
                            );
                            if (result['success'] != true) {
                              throw Exception(
                                result['message'] ?? 'Could not update the action point',
                              );
                            }
                            setState(() {
                              _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
                            });
                          } catch (e) {
                            AppTheme.showTopSnackBar(
                              context,
                              'Error updating action point: $e',
                              appBarHeight: kToolbarHeight + kTextTabBarHeight,
                            );
                          }
                        } : null,
                        
                      )
                    else
                      RemindersSection(
                        reminders: _formatReminders(appointment.reminders),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: HistorySection(historyItems: _buildHistoryItems(appointment)),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  List<HistoryItem> _buildHistoryItems(Appointment appointment) {
    return _history.map((entry) {
      final details = entry['details'] is Map
          ? Map<String, dynamic>.from(entry['details'] as Map)
          : <String, dynamic>{};
      final actor = entry['performed_by'] is Map
          ? Map<String, dynamic>.from(entry['performed_by'] as Map)
          : <String, dynamic>{};
      final createdAt = DateTimeUtils.parseServerTimestamp(entry['created_at']?.toString()) ?? DateTime.now();
      final eventType = (entry['type'] ?? entry['audit_action'] ?? entry['action_type'] ?? entry['action'] ?? '')
          .toString()
          .toLowerCase();
      final description = (entry['description'] ?? entry['action'] ?? '').toString();
      String actionLabel = description;
      String? eventDetail;

      if (eventType == 'action_point_added') {
        final actionPoint = details['action_point'] is Map
            ? Map<String, dynamic>.from(details['action_point'] as Map)
            : <String, dynamic>{};
        final pointDescription = (actionPoint['description'] ?? '').toString().trim();
        actionLabel = pointDescription.isNotEmpty
            ? 'Action point added: $pointDescription'
            : (description.isNotEmpty ? description : 'Action point added');
        final responsible = actionPoint['responsible_person']?.toString();
        if (responsible != null && responsible.trim().isNotEmpty) {
          eventDetail = 'Responsible: ${responsible.trim()}';
        }
      } else if (eventType == 'person_added_to_meet') {
        final person = details['person'] ?? details['attendee'] ?? details['person_added'];
        final personName = person is Map
            ? (person['name'] ?? person['full_name'] ?? person['email'])?.toString()
            : person?.toString();
        final name = personName?.trim() ?? '';
        actionLabel = name.isNotEmpty
            ? '$name was added to the meeting'
            : (description.isNotEmpty ? description : 'Person added to the meeting');
      } else if (eventType.contains('reschedul')) {
        actionLabel = description.isNotEmpty ? description : 'Rescheduled appointment';
      } else if (eventType.contains('edit')) {
        actionLabel = description.isNotEmpty ? description : 'Edited appointment';
      }

      if (actionLabel.isEmpty) actionLabel = 'Appointment updated';

      IconData icon = Icons.check_circle;
      Color iconColor = AppColors.teal;
      if (eventType == 'person_added_to_meet') {
        icon = Icons.person_add_alt_1;
        iconColor = AppColors.orange;
      } else if (eventType == 'action_point_added') {
        icon = Icons.add_task;
        iconColor = AppColors.green;
      } else if (eventType.contains('reschedul')) {
        icon = Icons.cached;
        iconColor = AppColors.orange;
      } else if (eventType.contains('cancelled')) {
        icon = Icons.cancel;
        iconColor = AppColors.red;
      } else if (eventType.contains('outcome')) {
        icon = Icons.task_alt;
        iconColor = AppColors.green;
      }

      return HistoryItem(
        action: actionLabel,
        details: [
          if (eventDetail != null) eventDetail,
          'by ${actor['name'] ?? entry['user_name'] ?? 'Unknown'}',
        ].join(' | '),
        timestamp: createdAt,
        icon: icon,
        iconColor: iconColor,
      );
    }).toList();
  }

  String _formatHeldAt(String heldAt) {
    try {
      final dateTime = DateTime.parse(heldAt);
      final formattedDate = DateTimeUtils.formatDateFromDateTime(dateTime);
      final formattedTime = DateTimeUtils.formatTimeFromDateTime(dateTime);
      return '$formattedDate at $formattedTime';
    } catch (e) {
      return heldAt;
    }
  }

  List<String> _formatReminders(List<Map<String, dynamic>> reminders) {
    // Filter out reminders with null or invalid minutes_before
    final validReminders = reminders.where((r) {
      final minutes = r['minutes_before'];
      return minutes != null && minutes is int && minutes > 0;
    }).toList();

    if (validReminders.isEmpty) {
      return const ['5 hrs before', '30 min before'];
    }

    return validReminders.map((r) {
      final minutes = r['minutes_before'] as int;
      if (minutes < 60) return '$minutes min before';
      final hours = (minutes / 60).floor();
      final remainingMins = minutes % 60;
      if (remainingMins == 0) return '$hours hr${hours > 1 ? 's' : ''} before';
      return '$hours hr${hours > 1 ? 's' : ''} $remainingMins min before';
    }).toList();
  }
}

class _EditAppointmentSheet extends StatefulWidget {
  final Appointment appointment;

  const _EditAppointmentSheet({required this.appointment});

  @override
  State<_EditAppointmentSheet> createState() => _EditAppointmentSheetState();
}

class _EditAppointmentSheetState extends State<_EditAppointmentSheet> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late final TextEditingController _durationController;
  late final TextEditingController _locationController;
  late final TextEditingController _onlineLinkController;
  bool _saving = false;
  bool _cancelling = false;
  String _locationType = 'physical';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.tryParse(widget.appointment.appointmentDate) ?? DateTime.now();
    _selectedTime = _parseTime(widget.appointment.startTime);
    _durationController = TextEditingController(text: '${widget.appointment.durationMinutes}');
    _locationController = TextEditingController(text: widget.appointment.location ?? '');
    _onlineLinkController = TextEditingController(
      text: widget.appointment.onlineLink ??
          (widget.appointment.locationType == 'online'
              ? widget.appointment.location ?? ''
              : ''),
    );
    _locationType = widget.appointment.locationType ?? 'physical';
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _durationController.dispose();
    _locationController.dispose();
    _onlineLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate.isBefore(now) ? now : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final result = await ApiService.updateAppointment(
      appointmentId: widget.appointment.id,
      auditAction: 'rescheduled',
      purpose: widget.appointment.purpose,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      startTime: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
      durationMinutes: int.parse(_durationController.text),
      location: _locationType == 'physical'
          ? _locationController.text.trim()
          : _onlineLinkController.text.trim(),
      locationType: _locationType,
      onlineLink: _locationType == 'online' ? _onlineLinkController.text.trim() : null,
      attendees: widget.appointment.attendeeDetails,
      reminders: widget.appointment.reminders,
      );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      AppTheme.showTopSnackBar(
        context,
        result['message'] ?? 'Failed to update appointment',
        appBarHeight: kToolbarHeight + kTextTabBarHeight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Text(
                'Reschedule appointment',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 4),
              Text(
                widget.appointment.purpose,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),
                      const Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SelectionField(
                              icon: Icons.calendar_today_outlined,
                              label: DateFormat('d MMM yyyy').format(_selectedDate),
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SelectionField(
                              icon: Icons.schedule_outlined,
                              label: _selectedTime.format(context),
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                              validator: (value) {
                                final duration = int.tryParse(value ?? '');
                                return duration == null || duration < 15 ? 'Min 15 minutes' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('LOCATION TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _locationType = 'physical'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _locationType == 'physical' ? AppColors.orange.withOpacity(0.12) : Colors.white,
                                  border: Border.all(color: _locationType == 'physical' ? AppColors.orange : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Physical',
                                  style: TextStyle(
                                    color: _locationType == 'physical' ? AppColors.orange : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _locationType = 'online'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _locationType == 'online' ? AppColors.orange.withOpacity(0.12) : Colors.white,
                                  border: Border.all(color: _locationType == 'online' ? AppColors.orange : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Virtual / Online',
                                  style: TextStyle(
                                    color: _locationType == 'online' ? AppColors.orange : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_locationType == 'physical')
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(labelText: 'Physical Location'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                        ),
                      if (_locationType == 'online')
                        TextFormField(
                          controller: _onlineLinkController,
                          decoration: const InputDecoration(labelText: 'Meeting Link'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                        ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving || _cancelling
                              ? null
                              : () {
                                  setState(() => _cancelling = true);
                                  Navigator.pop(context);
                                },
                          child: _cancelling
                              ? const SizedBox(width: 14, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving || _cancelling ? null : _save,
                          child: _saving
                              ? const SizedBox(width: 14, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Save changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SelectionField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
