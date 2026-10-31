import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/next_appointment_card.dart';
import '../widgets/stat_cards_row.dart';
import '../utils/dashboard_utils.dart';
import '../utils/date_time_utils.dart';
import '../services/live_refresh.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String _userName = 'there';
  bool _canManageAppointments = false;
  bool _canExportReports = false;
  String _selectedCategory = 'upcoming'; // upcoming, held, missed, actions

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _loadUserName();
    _loadPermissions();
    _loadSummary();

    // Refresh the dashboard when another screen signals an update
    liveRefresh.addListener(_loadSummary);
  }

  Future<void> _openNewAppointment() async {
    await Navigator.pushNamed(context, '/new-appointment');
    if (mounted) _loadSummary(); // reload when we come back
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

  Future<void> _loadUserName() async {
    final name = await ApiService.getUserName();
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.pushNamed(context, '/profile');
    if (mounted) _loadUserName();
  }

  Future<void> _loadSummary() async {
    try {
      final data = await ApiService.getDashboardSummary();

      if (!mounted) return;

      setState(() {
        _summary = normalizeDashboardPayload(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAppointmentDetails(int appointmentId) async {
    await Navigator.pushNamed(
      context,
      '/appointment-details',
      arguments: {'appointmentId': appointmentId},
    );
    if (mounted) _loadSummary();
  }

  @override
  void dispose() {
    liveRefresh.removeListener(_loadSummary);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _summary?['next_appointment'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NextAppointmentCard(
                            appointment: next,
                            onTap: next != null && next['id'] != null
                                ? () =>
                                      _openAppointmentDetails(next['id'] as int)
                                : null,
                          ),
                          const SizedBox(height: 20),
                          StatCardsRow(
                            upcoming: _summary?['upcoming'] ?? 0,
                            held: _summary?['held'] ?? 0,
                            missed: _summary?['missed'] ?? 0,
                            actionsDue: _summary?['action_points_pending'] ?? 0,
                            selectedCategory: _selectedCategory,
                            onCategoryChanged: (category) =>
                                setState(() => _selectedCategory = category),
                          ),
                          const SizedBox(height: 16),
                          _buildCategoryAppointments(),
                        ],
                      ),
                    ),
                  ),
                ),
                //const SizedBox(height: 80),
              ],
            ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 2 && _canExportReports)
            Navigator.pushNamed(context, '/reports');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: _canManageAppointments ? _openNewAppointment : null,
        showReports: _canExportReports,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        16 + MediaQuery.of(context).padding.top,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        //borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${greetingForNow()}, $_userName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_summary?['upcoming'] ?? 0} appointments today',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/notifications'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: 'Open profile',
                child: InkWell(
                  onTap: _openProfile,
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.orange,
                    child: Text(
                      _initials(_userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAppointments() {
    final category = _selectedCategory;
    final List<Map<String, dynamic>> appointments =
        _extractCategoryAppointments(category);

    // Sort appointments based on category
    if (category == 'held') {
      // Sort by held_at (recording date) latest first
      appointments.sort((a, b) {
        final heldAtA =
            a['held_at'] ?? a['appointment_date'] ?? a['date'] ?? '';
        final heldAtB =
            b['held_at'] ?? b['appointment_date'] ?? b['date'] ?? '';
        return heldAtB.toString().compareTo(heldAtA.toString());
      });
    } else if (category == 'missed') {
      // Sort by appointment_date latest first
      appointments.sort((a, b) {
        final dateA =
            a['appointment_date'] ?? a['date'] ?? a['scheduled_at'] ?? '';
        final dateB =
            b['appointment_date'] ?? b['date'] ?? b['scheduled_at'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      });
    } else if (category == 'actions') {
      // Sort by due_date earliest first
      appointments.sort((a, b) {
        final dueA = a['due_date'] ?? a['date'] ?? '';
        final dueB = b['due_date'] ?? b['date'] ?? '';
        return dueA.toString().compareTo(dueB.toString());
      });
    }

    final displayLimit = appointments.length > 5
        ? appointments.sublist(0, 5)
        : appointments;

    // Get category title and button text
    String categoryTitle;
    String buttonText;
    Color buttonColor;

    switch (category) {
      case 'held':
        categoryTitle = 'HELD APPOINTMENTS';
        buttonText = 'View details';
        buttonColor = AppColors.navy;
        break;
      case 'missed':
        categoryTitle = 'MISSED APPOINTMENTS';
        buttonText = 'Reschedule';
        buttonColor = AppColors.red;
        break;
      case 'actions':
        categoryTitle = 'ACTIONS DUE';
        buttonText = 'View details';
        buttonColor = AppColors.navy;
        break;
      default:
        categoryTitle = 'UPCOMING APPOINTMENTS';
        buttonText = 'View details';
        buttonColor = AppColors.navy;
    }

    if (displayLimit.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${category.toLowerCase()}',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryTitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...displayLimit.map<Widget>((apt) {
            final item = apt is Map ? apt : <String, dynamic>{};
            // For action points, use appointment_id to navigate to the parent appointment
            // For regular appointments, use id
            final id = category == 'actions'
                ? (item['appointment_id'] ?? item['appointmentId'])
                : (item['id'] ??
                      item['appointment_id'] ??
                      item['appointmentId']);
            final appointmentId = int.tryParse(id?.toString() ?? '');
            final title =
                item['purpose'] ??
                item['title'] ??
                item['description'] ??
                'Appointment';
            final dateValue =
                item['appointment_date'] ??
                item['date'] ??
                item['due_date'] ??
                'No date';
            final timeValue = item['start_time'] ?? item['time'] ?? '';

            // Format subtitle based on category
            String subtitle;
            if (category == 'held' && item['held_at'] != null) {
              try {
                subtitle =
                    'Held on ${DateTimeUtils.formatServerTimestamp(item['held_at'].toString())}';
              } catch (e) {
                subtitle = _formatAppointmentDateTime(
                  dateValue.toString(),
                  timeValue.toString(),
                );
              }
            } else if (category == 'actions') {
              subtitle = (item['due_date'] ?? item['date'] ?? 'No due date')
                  .toString();
            } else {
              subtitle = _formatAppointmentDateTime(
                dateValue.toString(),
                timeValue.toString(),
              );
            }

            return Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEAEAEA)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton(
                    onPressed: appointmentId == null
                        ? null
                        : () {
                            if (category == 'missed') {
                              _rescheduleAppointment(appointmentId);
                            } else {
                              _openAppointmentDetails(appointmentId);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _rescheduleAppointment(int appointmentId) async {
    // Navigate to appointment details first, then user can reschedule from there
    await Navigator.pushNamed(
      context,
      '/appointment-details',
      arguments: {'appointmentId': appointmentId},
    );
    if (mounted) _loadSummary();
  }

  // Turns "Vincent Mugisha" into "VM". Falls back to "?" if there's

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty || name == 'there') return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _formatAppointmentDateTime(String dateValue, String timeValue) {
    return DateTimeUtils.formatDateTime(dateValue, timeValue);
  }

  // _showCategoryAppointments and _showActionPoints are no longer needed
  // Categories are now handled in _buildCategoryAppointments

  List<Map<String, dynamic>> _extractCategoryAppointments(String category) {
    final summary = normalizeDashboardPayload(_summary ?? {});

    // For actions, use different keys
    if (category == 'actions') {
      final source = summary['action_points'] ?? summary['action_points_due'];
      if (source is List) {
        return source
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return const [];
    }

    final keys = [
      '${category}_appointments',
      '${category}Appointments',
      '${category}_items',
      '${category}Items',
      'appointments_${category}',
      'appointments${category[0].toUpperCase()}${category.substring(1)}',
      category,
    ];

    for (final key in keys) {
      final value = summary[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (value is Map) {
        final extracted = extractListFromDashboard(value);
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
    }

    for (final value in summary.values) {
      if (value is List) {
        final matches = value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (matches.isNotEmpty && matches.first.containsKey('status')) {
          return matches;
        }
      }
    }

    return const [];
  }
}
