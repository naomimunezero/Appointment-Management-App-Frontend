import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
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
    }
  }

  void _missedReschedule() {
    // Navigate to new appointment screen with this appointment prefilled
    Navigator.pushNamed(
      context,
      '/new-appointment',
      arguments: {'rescheduleAppointmentId': widget.appointmentId},
    );
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
                    onMissedReschedule: _missedReschedule,
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
    // Parse and build history items from appointment data
    // This is a basic implementation - extend based on your API response
    return [
      HistoryItem(
        action: 'Created',
        details: 'by you',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        icon: Icons.check_circle,
        iconColor: AppColors.teal,
      ),
      if (appointment.status != 'upcoming')
        HistoryItem(
          action: 'Rescheduled',
          details: '9:00 - 10:00 AM by you',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          icon: Icons.cached,
          iconColor: AppColors.orange,
        ),
    ];
  }
}
