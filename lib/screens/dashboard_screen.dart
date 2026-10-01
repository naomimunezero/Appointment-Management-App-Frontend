import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/next_appointment_card.dart';
import '../widgets/stat_cards_row.dart';
import '../utils/dashboard_utils.dart';
import '../utils/date_time_utils.dart';

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

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _loadUserName();
    _loadPermissions();
    _loadSummary();
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
    if (name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadSummary() async {
    final data = await ApiService.getDashboardSummary();
    setState(() {
      _summary = normalizeDashboardPayload(data);
      _loading = false;
    });
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
                                ? () => _openAppointmentDetails(next['id'] as int)
                                : null,
                          ),
                          const SizedBox(height: 20),
                          StatCardsRow(
                            upcoming: _summary?['upcoming'] ?? 0,
                            held: _summary?['held'] ?? 0,
                            missed: _summary?['missed'] ?? 0,
                            actionsDue: _summary?['action_points_pending'] ?? 0,
                            //onUpcomingTap: () => _showCategoryAppointments('upcoming'),
                            onHeldTap: () => _showCategoryAppointments('held'),
                            onMissedTap: () => _showCategoryAppointments('missed'),
                            onActionsTap: () => _showActionPoints(),
                          ),
                          const SizedBox(height: 16),
                          _buildUpcomingAppointments(),
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
          if (index == 2 && _canExportReports) Navigator.pushNamed(context, '/reports');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: _canManageAppointments ? () => Navigator.pushNamed(context, '/new-appointment') : null,
        showReports: _canExportReports,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 16 + MediaQuery.of(context).padding.top, 20, 24),
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
              Text('${greetingForNow()}, $_userName',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${_summary?['upcoming'] ?? 0} appointments today',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/notifications'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.orange,
                child: Text(_initials(_userName),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointments() {
    final dynamic rawAppointments =
        _summary?['upcoming_appointments'] ??
        _summary?['upcomingAppointments'] ??
        _summary?['upcoming_items'] ??
        _summary?['upcomingItems'] ??
        const [];

    final List appointments = rawAppointments is List
        ? rawAppointments
        : (rawAppointments is Map ? extractListFromDashboard(rawAppointments) : const []);

    final availableAppointments = appointments.isEmpty ? _extractCategoryAppointments('upcoming') : appointments;
    final displayLimit = availableAppointments.length > 5 ? availableAppointments.sublist(0, 5) : availableAppointments;

    if (displayLimit.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UPCOMING APPOINTMENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No upcoming appointments',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UPCOMING APPOINTMENTS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...displayLimit.map<Widget>((apt) {
            final item = apt is Map ? apt : <String, dynamic>{};
            final id = item['id'] ?? item['appointment_id'] ?? item['appointmentId'];
            final appointmentId = int.tryParse(id?.toString() ?? '');
            final title = item['purpose'] ?? item['title'] ?? 'Appointment';
            final dateValue = item['appointment_date'] ?? item['date'] ?? 'No date';
            final timeValue = item['start_time'] ?? item['time'] ?? '';
            final subtitle = _formatAppointmentDateTime(dateValue.toString(), timeValue.toString());

            return Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEAEAEA)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      
                      ElevatedButton(
                        onPressed: appointmentId == null
                            ? null
                            : () => _openAppointmentDetails(appointmentId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
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
                        child: const Text(
                          'View details',
                          style: TextStyle(
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

  // Turns "Vincent Mugisha" into "VM". Falls back to "?" if there's
  
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty || name == 'there') return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String _formatAppointmentDateTime(String dateValue, String timeValue) {
    return DateTimeUtils.formatDateTime(dateValue, timeValue);
  }

  void _showCategoryAppointments(String category) {
    final items = _extractCategoryAppointments(category);
    if (items.isEmpty) {
      AppTheme.showTopSnackBar(context, 'No $category appointments available right now.');
      return;
    }

    // Sort items by latest first
    // For held appointments, sort by held_at (recording date)
    // For other categories, sort by appointment_date
    items.sort((a, b) {
      if (category == 'held') {
        final heldAtA = a['held_at'] ?? a['appointment_date'] ?? a['date'] ?? '';
        final heldAtB = b['held_at'] ?? b['appointment_date'] ?? b['date'] ?? '';
        return heldAtB.toString().compareTo(heldAtA.toString());
      } else {
        final dateA = a['appointment_date'] ?? a['date'] ?? a['scheduled_at'] ?? '';
        final dateB = b['appointment_date'] ?? b['date'] ?? b['scheduled_at'] ?? '';
        return dateB.toString().compareTo(dateA.toString());
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Text(
              category.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final title = item['purpose'] ?? item['title'] ?? item['name'] ?? 'Appointment';
                  final date = item['appointment_date'] ?? item['date'] ?? item['scheduled_at'] ?? 'No date';
                  final time = item['start_time'] ?? item['time'] ?? '';
                  final id = item['id'] ?? item['appointment_id'] ?? item['appointmentId'];
                  final appointmentId = int.tryParse(id?.toString() ?? '');

                  // For held appointments, show recording date/time if available
                  String subtitle;
                  if (category == 'held' && item['held_at'] != null) {
                    final heldAt = item['held_at'];
                    try {
                      subtitle = 'Held on ${DateTimeUtils.formatServerTimestamp(heldAt.toString())}';
                    } catch (e) {
                      subtitle = _formatAppointmentDateTime(date.toString(), time.toString());
                    }
                  } else {
                    subtitle = _formatAppointmentDateTime(date.toString(), time.toString());
                  }

                  return ListTile(
                    title: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: appointmentId == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            _openAppointmentDetails(appointmentId);
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActionPoints() {
    final items = (_summary?['action_points'] ?? _summary?['action_points_due'] ?? const []) as List;
    if (items.isEmpty) {
      AppTheme.showTopSnackBar(context, 'No action points due yet.');
      return;
    }

    // Sort action points by due date (earliest first)
    items.sort((a, b) {
      final dueA = a['due_date'] ?? a['date'] ?? '';
      final dueB = b['due_date'] ?? b['date'] ?? '';
      return dueA.toString().compareTo(dueB.toString());
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text('ACTIONS DUE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index] is Map ? items[index] as Map : <String, dynamic>{};
                  final title = item['title'] ?? item['description'] ?? 'Action point';
                  final due = item['due_date'] ?? item['date'] ?? 'No due date';
                  return ListTile(
                    title: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(due.toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractCategoryAppointments(String category) {
    final summary = normalizeDashboardPayload(_summary ?? {});

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
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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
        final matches = value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (matches.isNotEmpty && matches.first.containsKey('status')) {
          return matches;
        }
      }
    }

    return const [];
  }
}
