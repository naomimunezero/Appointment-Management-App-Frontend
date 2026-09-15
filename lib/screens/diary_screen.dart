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

  // Appointments grouped by "yyyy-MM-dd" key.
  Map<String, List<Map<String, dynamic>>> _appointmentsByDate = {};

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _selectedDate = DateTime.now();
    _weekStart = startOfWeek(_selectedDate);
    _loadWeek();
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
                  Icons.calendar_today,
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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadWeek,
                child: _buildDayList(),
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

          if (index == 2) {
            Navigator.pushNamed(context, '/reports');
          }

          if (index == 3) {
            Navigator.pushNamed(context, '/settings');
          }
        },
        onAddTap: () {
          Navigator.pushNamed(
            context,
            '/new-appointment',
          );
        },
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
      setState(() {
        _selectedDate = picked;
        _weekStart = startOfWeek(picked);
      });

      _loadWeek();
    }
  }

  Widget _buildDayList() {
    // Show only appointments for the selected date.
    final dateKey = _dateKey(_selectedDate);

    final appointments =
        _appointmentsByDate[dateKey] ?? [];

    if (appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),

          Center(
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 48,
                  color: Colors.grey[300],
                ),

                const SizedBox(height: 16),

                Text(
                  'No appointments on '
                  '${_formatDateForDisplay(_selectedDate)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        100,
      ),

      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 12,
                  bottom: 10,
                ),

                child: Text(
                  formatDayHeader(_selectedDate),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              ...appointments.map(
                (a) => DiaryAppointmentCard(
                  appointment: a,
                  onTap: () {
                    final appointmentId =
                        a['id'] as int?;

                    if (appointmentId != null) {
                      Navigator.pushNamed(
                        context,
                        '/appointment-details',
                        arguments: {
                          'appointmentId': appointmentId,
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
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