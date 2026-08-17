import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/diary_week_strip.dart';
import '../widgets/diary_appointment_card.dart';
import '../utils/diary_utils.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  bool _loading = true;

  // Appointments grouped by "yyyy-MM-dd" key.
  Map<String, List<Map<String, dynamic>>> _appointmentsByDate = {};

  final Map<String, GlobalKey> _sectionKeys = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _weekStart = startOfWeek(_selectedDate);
    _loadWeek();
  }

  List<DateTime> get _weekDays => List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  // IMPORTANT: this expects ApiService.getAppointments(from, to) to exist —
  // see the note below the code for what to add to your ApiService.
  // Expected response: a List of appointment maps, each with at least
  // appointment_date ("2026-07-09"), start_time ("8:00 AM"), purpose,
  // person_to_meet, location, duration_minutes, status.
  Future<void> _loadWeek() async {
    setState(() => _loading = true);
    try {
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final results = await ApiService.getAppointments(_weekStart, weekEnd);

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final item in results) {
        final map = Map<String, dynamic>.from(item as Map);
        final key = (map['appointment_date'] ?? '').toString().substring(0, 10);
        grouped.putIfAbsent(key, () => []).add(map);
      }
      // Keep each day's list sorted by start time isn't guaranteed by the
      // API, but grouping order from the backend is usually fine since
      // it should already order by date/time.

      setState(() {
        _appointmentsByDate = grouped;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _appointmentsByDate = {};
        _loading = false;
      });
    }
  }

  void _onSelectDay(DateTime day) {
    setState(() => _selectedDate = day);
    final key = _sectionKeys[dateKey(day)];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final datesWithAppointments = _appointmentsByDate.keys.toSet();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(weekEnd),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DiaryWeekStrip(
                weekDays: _weekDays,
                selectedDate: _selectedDate,
                datesWithAppointments: datesWithAppointments,
                onSelect: _onSelectDay,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadWeek,
                      child: _buildDayList(),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) return;
          if (index == 2) Navigator.pushNamed(context, '/reports');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: () => Navigator.pushNamed(context, '/new-appointment'),
      ),
    );
  }

  Widget _buildHeader(DateTime weekEnd) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              const Text('My diary',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(formatWeekRange(_weekStart, weekEnd),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.tune, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDayList() {
    // Only show days that actually have appointments, in week order,
    // starting from the top of the week — matches the "continuous
    // agenda" feel of the design rather than 7 mostly-empty sections.
    final daysWithData = _weekDays.where((d) => _appointmentsByDate.containsKey(dateKey(d))).toList();

    if (daysWithData.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text('No appointments this week', style: TextStyle(color: Colors.grey)),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: daysWithData.map((day) {
        final key = dateKey(day);
        _sectionKeys.putIfAbsent(key, () => GlobalKey());
        final appointments = _appointmentsByDate[key]!;

        return Container(
          key: _sectionKeys[key],
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Text(
                  formatDayHeader(day),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...appointments.map((a) => DiaryAppointmentCard(
                    appointment: a,
                    onTap: () {
                      // TODO: wire this once the Appointment Detail screen
                      // is built — Navigator.pushNamed(context, '/appointment', arguments: a['id']);
                    },
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }
}
