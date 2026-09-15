import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../widgets/appointment_info_section.dart';
import '../widgets/meeting_with_section.dart';
import '../widgets/reminders_section.dart';
import '../widgets/history_section.dart';
import '../widgets/action_buttons_section.dart';

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

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
    _loadHistory();
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

  void _editAppointment() {
    // Navigate to new appointment screen with this appointment prefilled for editing
    Navigator.pushNamed(
      context,
      '/new-appointment',
      arguments: {'editAppointmentId': widget.appointmentId},
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Appointment'),
        centerTitle: true,
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Appointment Info Section
                AppointmentInfoSection(appointment: appointment),
                const SizedBox(height: 16),

                // Meeting With Section
                MeetingWithSection(
                  attendees: appointment.attendees,
                  sectionTitle: 'MEETING WITH',
                ),
                const SizedBox(height: 16),

                // Reminders Section
                RemindersSection(
                  reminders: const [
                    '5 hrs before / sent',
                    '30 min before',
                  ],
                ),
                const SizedBox(height: 16),

                // History Section
                HistorySection(
                  historyItems: _buildHistoryItems(appointment),
                ),
                const SizedBox(height: 16),

                // Action Buttons Section - Only show for upcoming appointments
                if (!_isHeldAppointment(appointment))
                  ActionButtonsSection(
                    onRecordOutcome: _recordOutcome,
                    onEdit: _editAppointment,
                    onReschedule: () => _rescheduleAppointment(appointment),
                  ),
                // For held appointments, show a summary badge
                if (_isHeldAppointment(appointment))
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.green.withOpacity(0.3)),
                    ),
                    child: Row(
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
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  List<HistoryItem> _buildHistoryItems(Appointment appointment) {
    return _history.map((entry) {
      final createdAt = DateTime.tryParse(entry['created_at'] ?? '') ?? DateTime.now();
      final action = (entry['action'] ?? '').toString();

      IconData icon = Icons.check_circle;
      Color iconColor = AppColors.teal;
      if (action.contains('rescheduled')) {
        icon = Icons.cached;
        iconColor = AppColors.orange;
      } else if (action.contains('cancelled')) {
        icon = Icons.cancel;
        iconColor = AppColors.red;
      } else if (action.contains('outcome')) {
        icon = Icons.task_alt;
        iconColor = AppColors.green;
      }

      return HistoryItem(
        action: action,
        details: 'by ${entry['user_name'] ?? 'Unknown'}',
        timestamp: createdAt,
        icon: icon,
        iconColor: iconColor,
      );
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.tryParse(widget.appointment.appointmentDate) ?? DateTime.now();
    _selectedTime = _parseTime(widget.appointment.startTime);
    _durationController = TextEditingController(text: '${widget.appointment.durationMinutes}');
    _locationController = TextEditingController(text: widget.appointment.location ?? '');
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
      purpose: widget.appointment.purpose,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      startTime: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
      durationMinutes: int.parse(_durationController.text),
      location: _locationController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to update appointment')),
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
                'Edit appointment',
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(labelText: 'Location'),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : () => Navigator.pop(context),
                          child: _saving
                              ? const SizedBox(width: 14, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
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
