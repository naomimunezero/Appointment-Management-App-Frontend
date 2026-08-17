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
  List<String> _activityLabels = [];
  List<int> _activityValues = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadSummary();
    _loadActivity(_period);
  }

  // The name was already saved locally at login/register time (see
  // ApiService.login/register) — so this is just a local read, no
  // network call needed.
  Future<void> _loadUserName() async {
    final name = await ApiService.getUserName();
    if (name != null && name.isNotEmpty) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadSummary() async {
    final data = await ApiService.getDashboardSummary();
    setState(() {
      _summary = data;
      _loading = false;
    });
  }

  // Loads bar-chart data for whichever period pill is selected.
  //
  // IMPORTANT — you'll need to add this method to ApiService:
  //   static Future<Map<String, dynamic>> getActivity(String period) async { ... }
  // It should call a backend endpoint that groups appointments by day (or
  // week, for longer ranges) for the chosen period, and return:
  //   { "labels": ["M","T","W","T","F","S","S"], "values": [0,2,0,3,1,0,0] }
  //
  // Until that endpoint exists, the catch block below keeps the screen
  // working by showing an empty chart instead of crashing.
  Future<void> _loadActivity(ActivityPeriod period) async {
    setState(() => _activityLoading = true);
    try {
      final data = await ApiService.getActivity(period.name);
      setState(() {
        _activityLabels = List<String>.from(data['labels'] ?? []);
        _activityValues = List<int>.from(data['values'] ?? []);
        _activityLoading = false;
      });
    } catch (_) {
      final labels = _fallbackLabels(period);
      setState(() {
        _activityLabels = labels;
        _activityValues = List.filled(labels.length, 0);
        _activityLoading = false;
      });
    }
  }

  List<String> _fallbackLabels(ActivityPeriod period) {
    switch (period) {
      case ActivityPeriod.today:
        return const ['Today'];
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
                          NextAppointmentCard(appointment: next),
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
                          ),
                          const SizedBox(height: 20),
                          _buildActivityCard(),
                          const SizedBox(height: 16),
                          ..._buildRecentActivity(),
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
              ? const SizedBox(height: 110, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : ActivityChart(labels: _activityLabels, values: _activityValues),
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

  List<Widget> _buildRecentActivity() {
    final List recent = _summary?['recent_activity'] ?? [];
    if (recent.isEmpty) return [const NoRecentActivity()];
    return recent.map<Widget>((item) {
      return RecentActivityItem(
        title: item['title'] ?? '',
        subtitle: item['subtitle'] ?? '',
        status: item['status'] ?? '',
      );
    }).toList();
  }
}
