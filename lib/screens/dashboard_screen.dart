import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/next_appointment_card.dart';
import '../widgets/stat_cards_row.dart';
import '../widgets/time_filter_tabs.dart';
import '../widgets/activity_chart.dart';
import '../widgets/recent_activity_item.dart';
import '../utils/dashboard_utils.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String _userName = 'there';

  ActivityPeriod _period = ActivityPeriod.thisWeek;
  bool _activityLoading = true;
  List<String> _dayLabels = [];
  List<int> _dayValues = [];
  List<String> _timeLabels = [];
  List<int> _timeValues = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadSummary();
    _loadActivity(_period);
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

  Future<void> _loadActivity(ActivityPeriod period) async {
    setState(() => _activityLoading = true);
    try {
      final data = await ApiService.getActivity(period.name);
      final demoSeries = demoActivitySeries(period.name);
      setState(() {
        _dayLabels = _extractLabels(data, ['day_labels', 'days_labels', 'labels', 'week_labels', 'week_days']).isNotEmpty
            ? _extractLabels(data, ['day_labels', 'days_labels', 'labels', 'week_labels', 'week_days'])
            : (demoSeries['day_labels'] as List).map((e) => e.toString()).toList();
        _dayValues = _extractValues(data, ['day_values', 'days_values', 'values', 'week_values', 'meetings']).isNotEmpty
            ? _extractValues(data, ['day_values', 'days_values', 'values', 'week_values', 'meetings'])
            : (demoSeries['day_values'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();
        _timeLabels = _extractLabels(data, ['time_labels', 'hour_labels', 'time_slots', 'slots', 'time']).isNotEmpty
            ? _extractLabels(data, ['time_labels', 'hour_labels', 'time_slots', 'slots', 'time'])
            : (demoSeries['time_labels'] as List).map((e) => e.toString()).toList();
        _timeValues = _extractValues(data, ['time_values', 'hour_values', 'appointment_counts', 'appointments']).isNotEmpty
            ? _extractValues(data, ['time_values', 'hour_values', 'appointment_counts', 'appointments'])
            : (demoSeries['time_values'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();

        _activityLoading = false;
      });
    } catch (_) {
      final demoSeries = demoActivitySeries(period.name);
      setState(() {
        _dayLabels = (demoSeries['day_labels'] as List).map((e) => e.toString()).toList();
        _dayValues = (demoSeries['day_values'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();
        _timeLabels = (demoSeries['time_labels'] as List).map((e) => e.toString()).toList();
        _timeValues = (demoSeries['time_values'] as List).map((e) => int.tryParse(e.toString()) ?? 0).toList();
        _activityLoading = false;
      });
    }
  }

  List<String> _extractLabels(Map<String, dynamic> source, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = source[key];
      if (value is List) {
        return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
      }
    }
    return const [];
  }

  List<int> _extractValues(Map<String, dynamic> source, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = source[key];
      if (value is List) {
        return value.map((e) => int.tryParse(e?.toString() ?? '') ?? 0).toList();
      }
    }
    return const [];
  }

  List<String> _fallbackLabels(ActivityPeriod period) {
    switch (period) {
      case ActivityPeriod.today:
        return const ['Now'];
      case ActivityPeriod.thisWeek:
      case ActivityPeriod.last7Days:
        return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      case ActivityPeriod.last2Weeks:
        return const ['W1', 'W2'];
      case ActivityPeriod.lastMonth:
        return const ['W1', 'W2', 'W3', 'W4'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _summary?['next_appointment'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          NextAppointmentCard(
                            appointment: next,
                            onTap: next != null && next['id'] != null
                                ? () {
                                    Navigator.pushNamed(
                                      context,
                                      '/appointment-details',
                                      arguments: {'appointmentId': next['id'] as int},
                                    );
                                  }
                                : null,
                          ),
                          const SizedBox(height: 20),
                          TimeFilterTabs(
                            selected: _period,
                            onChanged: (p) {
                              setState(() => _period = p);
                              _loadActivity(p);
                            },
                          ),
                          const SizedBox(height: 20),
                          StatCardsRow(
                            upcoming: _summary?['upcoming'] ?? 0,
                            held: _summary?['held'] ?? 0,
                            missed: _summary?['missed'] ?? 0,
                            actionsDue: _summary?['action_points_pending'] ?? 0,
                            onUpcomingTap: () => _showCategoryAppointments('upcoming'),
                            onHeldTap: () => _showCategoryAppointments('held'),
                            onMissedTap: () => _showCategoryAppointments('missed'),
                            onActionsTap: () => _showActionPoints(),
                          ),
                          const SizedBox(height: 20),
                          _buildActivityCard(),
                          const SizedBox(height: 16),
                          _buildRecentHeldAppointments(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 2) Navigator.pushNamed(context, '/reports');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: () => Navigator.pushNamed(context, '/new-appointment'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

  Widget _buildRecentHeldAppointments() {
    final dynamic rawAppointments =
        _summary?['recent_held_appointments'] ??
        _summary?['recentHeldAppointments'] ??
        _summary?['held_appointments'] ??
        _summary?['heldAppointments'] ??
        const [];

    final List appointments = rawAppointments is List
        ? rawAppointments
        : (rawAppointments is Map ? extractListFromDashboard(rawAppointments) : const []);

    final displayLimit = appointments.length > 5 ? appointments.sublist(0, 5) : appointments;

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
              'RECENT HELD APPOINTMENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No held appointments yet',
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
            'RECENT HELD APPOINTMENTS',
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
            final subtitle = 'Held ${_formatTimeDisplay(dateValue)}';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: appointmentId == null
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/appointment-details',
                          arguments: {'appointmentId': appointmentId},
                        );
                      },
                child: Container(
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'HELD',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVITY — ${_periodTitle()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _activityLoading
              ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ActivityChart(
                        title: 'MEETINGS',
                        labels: _dayLabels,
                        values: _dayValues,
                        accentColor: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ActivityChart(
                        title: 'TIME',
                        labels: _timeLabels,
                        values: _timeValues,
                        accentColor: AppColors.orange,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // Turns "Vincent Mugisha" into "VM". Falls back to "?" if there's
  // no name yet (e.g. still loading).
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty || name == 'there') return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String _periodTitle() {
    switch (_period) {
      case ActivityPeriod.today:
        return 'TODAY';
      case ActivityPeriod.thisWeek:
        return 'THIS WEEK';
      case ActivityPeriod.last7Days:
        return 'LAST 7 DAYS';
      case ActivityPeriod.last2Weeks:
        return 'LAST 2 WEEKS';
      case ActivityPeriod.lastMonth:
        return 'LAST MONTH';
    }
  }

  String _formatTimeDisplay(String value) {
    final text = value.toString().trim();
    if (text.isEmpty) return 'No time';

    if (text.contains('T')) {
      final datePart = text.split('T').first;
      final timePart = text.split('T').last;
      final cleanTime = timePart.split('.').first;
      return '$datePart $cleanTime';
    }

    return text;
  }

  void _showCategoryAppointments(String category) {
    final items = _extractCategoryAppointments(category);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $category appointments available right now.')),
      );
      return;
    }

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
                  final id = item['id'] ?? item['appointment_id'] ?? item['appointmentId'];
                  final appointmentId = int.tryParse(id?.toString() ?? '');

                  return ListTile(
                    title: Text(title.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(date.toString()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: appointmentId == null
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              '/appointment-details',
                              arguments: {'appointmentId': appointmentId},
                            );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No action points due yet.')),
      );
      return;
    }

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
