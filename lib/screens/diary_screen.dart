import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
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
  bool _canManageAppointments = false;
  bool _canExportReports = false;

  // Appointments grouped by "yyyy-MM-dd" key.
  Map<String, List<Map<String, dynamic>>> _appointmentsByDate = {};

  final ScrollController _scrollController = ScrollController();
  late final PageController _calendarController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _selectedDate = DateTime.now();
    _weekStart = startOfWeek(_selectedDate);
    _calendarController = PageController(initialPage: 1000, viewportFraction: 1 / 7);
    _loadPermissions();
    _loadWeek();
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

  Future<void> _loadWeek() async {
    setState(() => _loading = true);

    try {
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final results = await ApiService.getAppointments(
        _weekStart,
        weekEnd,
      );

      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final item in results) {
        final map = Map<String, dynamic>.from(item as Map);

        final rawDate = (map['appointment_date'] ?? '').toString();

        if (rawDate.length < 10) {
          continue;
        }

        final key = rawDate.substring(0, 10);

        grouped.putIfAbsent(key, () => []).add(map);
      }

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

  Future<void> _refreshToToday() async {
    final today = DateTime.now();
    setState(() {
      _selectedDate = today;
      _weekStart = startOfWeek(today);
    });
    if (_calendarController.hasClients) {
      _calendarController.jumpToPage(1000); // page 1000 = today
    }
    await _loadWeek();
  }

  Future<void> _openAppointmentDetails(int appointmentId) async {
    await Navigator.pushNamed(
      context,
      '/appointment-details',
      arguments: {'appointmentId': appointmentId},
    );
    if (mounted) _loadWeek();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: AppColors.background,

      // NAVY APP BAR
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,

        titleSpacing: 20,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My diary',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatWeekRange(_weekStart, weekEnd),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.filter_alt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),

      // BODY
      body: SafeArea(
        top: false,
        child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: _buildCalendarStrip(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshToToday,
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildDayList(),
                    ),
                  ),
                ],
              ),
      ),

      // BOTTOM NAVIGATION
      bottomNavigationBar: AppBottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/dashboard');
          }

          if (index == 1) {
            return;
          }

          if (index == 2 && _canExportReports) {
            Navigator.pushNamed(context, '/reports');
          }

          if (index == 3) {
            Navigator.pushNamed(context, '/settings');
          }
        },
        onAddTap: _canManageAppointments ? () {
          Navigator.pushNamed(
            context,
            '/new-appointment',
          );
        } : null,
        showReports: _canExportReports,
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final page = 1000 + DateTime(picked.year, picked.month, picked.day)
        .difference(DateTime(now.year, now.month, now.day)).inDays;
      setState(() {
        _selectedDate = picked;
        _weekStart = startOfWeek(picked);
      });
      _calendarController.jumpToPage(page);
      _loadWeek();
    }
  }

  Widget _buildCalendarStrip() {
    return SizedBox(
          height: 78,
          child: PageView.builder(
            controller: _calendarController,
            pageSnapping: false,
            onPageChanged: (page) {
              final today = DateTime.now();
              final centerDate = DateTime(today.year, today.month, today.day).add(Duration(days: page - 1000));
              final start = startOfWeek(centerDate);
              if (dateKey(start) != dateKey(_weekStart)) {
               setState(() => _weekStart = start);
               _loadWeek();
              }
            },
            itemBuilder: (context, page) {
              final today = DateTime.now();
                final date = DateTime(today.year, today.month, today.day).add(Duration(days: page - 1000));
                  final selected = dateKey(date) == dateKey(_selectedDate);
                  final hasAppointments = (_appointmentsByDate[dateKey(date)] ?? []).isNotEmpty;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _selectedDate = date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected ? AppColors.orange : Colors.white,
                            border: Border.all(color: selected ? AppColors.orange : const Color(0xFFE1E6EE)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(weekdayShort[date.weekday - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.blueGrey)),
                            const SizedBox(height: 4),
                            Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.navy)),
                            const SizedBox(height: 2),
                            Icon(Icons.circle, size: 4, color: hasAppointments ? (selected ? Colors.white : AppColors.teal) : Colors.transparent),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
              );

  }

  Widget _buildDayList() => ListView(
    controller: _scrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    children: _buildUpcomingDaySections(),
  );

  List<Widget> _buildUpcomingDaySections() {
    final result = <Widget>[];
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    for (var date = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        !date.isAfter(_weekStart.add(const Duration(days: 6)));
        date = date.add(const Duration(days: 1))) {
      final appointments = _appointmentsByDate[_dateKey(date)] ?? [];
      if (appointments.isEmpty) continue;
      final heading = _dateKey(date) == todayKey ? 'TODAY · ${formatDayHeader(date)}' : formatDayHeader(date);
      result.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Text(heading, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 0.5)),
      ));
      result.addAll(appointments.map((a) => DiaryAppointmentCard(
        appointment: a,
        onTap: () {
          final id = int.tryParse('${a['id'] ?? ''}');
          if (id != null) _openAppointmentDetails(id);
        },
      )));
    }
    if (result.isEmpty) {
      result.add(Padding(
        padding: const EdgeInsets.only(top: 52),
        child: Center(child: Text('No upcoming appointments from ${_formatDateForDisplay(_selectedDate)}', style: TextStyle(color: Colors.grey[600]))),
      ));
    }
    return result;
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateForDisplay(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }
}
