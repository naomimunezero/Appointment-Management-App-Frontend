
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'appointment_details_screen.dart';
import '../utils/date_time_utils.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool _loading = true;

  // Currently selected filter
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService.getNotifications();

      print('NOTIFICATIONS SCREEN RESPONSE: $response');
      print('NOTIFICATIONS COUNT: ${response.length}');

      if (!mounted) return;

      setState(() {
        notifications = response;
        _loading = false;
      });

      print('SET STATE COMPLETED - NOTIFICATIONS LIST LENGTH: ${notifications.length}');

      for (final n in response) {
        if (n['type'] == 'reminder' && n['appointment_id'] != null) {
          final remindAt = DateTime.tryParse(n['time'] ?? '');
          if (remindAt != null) {
            await NotificationService.scheduleReminder(
              id: n['appointment_id'] + (remindAt.hour * 100000),
              title: n['purpose'] ?? 'Appointment reminder',
              body: 'Meeting on ${DateTimeUtils.friendlyMeetingDate(n['appointment_date'], n['start_time'])}',
              scheduledAt: remindAt.toLocal(),
            );
          }
        }
      }
    } catch (e) {
      print('NOTIFICATIONS SCREEN ERROR: $e');

      if (!mounted) return;

      setState(() {
        notifications = [];
        _loading = false;
      });
    }
  }

  // Filter notifications according to selected type
  List<dynamic> get _filteredNotifications {
    print('FILTERING - Selected type: $_selectedType, Total notifications: ${notifications.length}');

    if (_selectedType == 'all') {
      print('RETURNING ALL NOTIFICATIONS: ${notifications.length}');
      return notifications;
    }

    final filtered = notifications.where((notification) {
      return notification['type']?.toString() == _selectedType;
    }).toList();

    print('FILTERED COUNT: ${filtered.length}');
    return filtered;
  }

  // Change selected filter
  void _selectType(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  // Get color according to notification type
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'reminder':
        return AppColors.orange;

      case 'activity':
        return AppColors.navy;

      case 'overdue':
        return AppColors.red;

      default:
        return AppColors.navy;
    }
  }

  // Format notification time
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) {
      return '';
    }

    try {
      final dateTime = DateTime.parse(time).toLocal();

      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');

      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;

      return '$displayHour:$minute $period';
    } catch (_) {
      // If the value is only a date, such as 2026-08-10,
      // just return the original value.
      return time;
    }
  }

  // Get section label
  String _getSectionTitle(String type) {
    switch (type) {
      case 'reminder':
        return 'REMINDERS';

      case 'activity':
        return 'ACTIVITY';

      case 'overdue':
        return 'OVERDUE';

      default:
        return 'NOTIFICATIONS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // Refresh button
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                10,
              ),
              color: AppColors.background,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedType == 'all',
                      onTap: () => _selectType('all'),
                    ),

                    const SizedBox(width: 8),

                    _FilterChip(
                      label: 'Reminders',
                      selected: _selectedType == 'reminder',
                      onTap: () => _selectType('reminder'),
                    ),

                    const SizedBox(width: 8),

                    _FilterChip(
                      label: 'Activity',
                      selected: _selectedType == 'activity',
                      onTap: () => _selectType('activity'),
                    ),

                    const SizedBox(width: 8),

                    _FilterChip(
                      label: 'Overdue',
                      selected: _selectedType == 'overdue',
                      onTap: () => _selectType('overdue'),
                    ),
                  ],
                ),
              ),
            ),


            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  _selectedType == 'all'
                                      ? 'No notifications right now'
                                      : 'No ${_selectedType == 'reminder'
                                          ? 'reminders'
                                          : _selectedType == 'activity'
                                              ? 'activity'
                                              : 'overdue notifications'} right now',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              6,
                              16,
                              20,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final notification = Map<String, dynamic>.from(filtered[index], );

                              final type = notification['type']?.toString() ?? '';
                              final title = notification['title']?.toString() ?? '';
                              final message = notification['message']?.toString() ?? '';
                              final time = notification['time']?.toString() ?? '';

                              final appointmentId = notification['appointment_id'];
                              final purpose = notification['purpose']?.toString();
                              final appointmentDate = notification['appointment_date']?.toString();
                              final startTime = notification['start_time']?.toString();
                              final location = notification['location']?.toString();

                              final hasMeetingInfo = purpose != null && purpose.isNotEmpty;
                              final cardTitle = hasMeetingInfo ? purpose : title;
                              final cardBody = hasMeetingInfo
                                  ? 'Meeting on ${DateTimeUtils.friendlyMeetingDate(appointmentDate, startTime)}'
                                  : message;

                              String displayTime = _formatTime(time);
                              if (type == 'reminder' && appointmentDate != null) {
                                try {
                                  final dt = DateTime.parse('$appointmentDate ${startTime ?? "00:00:00"}');
                                  displayTime = DateTimeUtils.relativeCountdown(dt);
                                } catch (_) {}
                              }

                              // Show section title when the notification
                              // type changes.
                              bool showSection = index == 0;

                              if (index > 0) {
                                final previous =
                                    Map<String, dynamic>.from(
                                  filtered[index - 1],
                                );

                                final previousType =
                                    previous['type']?.toString() ?? '';

                                showSection = previousType != type;
                              }

                              return _NotificationCard(
                                color: _getNotificationColor(type),
                                title: cardTitle,        // CHANGED — was: title
                                body: cardBody,           // CHANGED — was: message
                                time: displayTime,
                                sectionTitle: _getSectionTitle(type),
                                showSection: showSection,
                                appointmentId: appointmentId,
                                purpose: purpose,
                                appointmentDate: appointmentDate,
                                startTime: startTime,
                                location: location,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.navy
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.navy
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// NOTIFICATION CARD
// =====================================================================

class _NotificationCard extends StatelessWidget {
  final Color color;
  final String title;
  final String body;
  final String time;
  final String sectionTitle;
  final bool showSection;
  final int? appointmentId;        // ADD
  final String? purpose;            // ADD
  final String? appointmentDate;    // ADD
  final String? startTime;          // ADD
  final String? location; 

  const _NotificationCard({
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.sectionTitle,
    required this.showSection,
    this.appointmentId,             // ADD
    this.purpose,                    // ADD
    this.appointmentDate,            // ADD
    this.startTime,                  // ADD
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        if (showSection) ...[
          const SizedBox(height: 8),

          Text(
            sectionTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 8),
        ],

        // Notification card
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Colored left border
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14),
                    ),
                  ),
                ),

                // Card content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.navy,
                          ),
                        ),

                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 5),

                          Text(
                            body,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              height: 1.35,
                            ),
                          ),
                        ],

                        if (time.isNotEmpty || appointmentId != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (time.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    time,
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              if (appointmentId != null)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AppointmentDetailsScreen(appointmentId: appointmentId!)),
                                    );
                                  },
                                  child: Text(
                                    'View details →',
                                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],

                                                
                        if (location != null && location!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(location!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ),
                          ],
                        ),
                      ],
                      
                      ],                   
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

