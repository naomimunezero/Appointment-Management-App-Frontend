import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/report_summary.dart';
import '../models/appointment.dart';
import '../widgets/stat_cards_row.dart';
import '../widgets/report_widgets.dart';
import '../widgets/bottom_nav_bar.dart';
import 'appointment_preview_screen.dart';

enum ReportRange { thisWeek, last7, last2Weeks }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportRange _range = ReportRange.last7;
  ReportSummary? _report;
  Appointment? _selected;
  bool _loading = true;

  DateTimeRange _rangeFor(ReportRange r) {
    final now = DateTime.now();
    switch (r) {
      case ReportRange.thisWeek:
        return DateTimeRange(start: now.subtract(Duration(days: now.weekday - 1)), end: now);
      case ReportRange.last7:
        return DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
      case ReportRange.last2Weeks:
        return DateTimeRange(start: now.subtract(const Duration(days: 14)), end: now);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _selected = null; });
    final range = _rangeFor(_range);
    final fmt = DateFormat('yyyy-MM-dd');
    final report = await ApiService.getReports(fmt.format(range.start), fmt.format(range.end));
    setState(() {
      _report = report;
      _selected = report.appointments.isNotEmpty ? report.appointments.first : null;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _rangeChip(String label, ReportRange value) {
    final selected = _range == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) { setState(() => _range = value); _load(); },
        selectedColor: AppColors.navy,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.navy,
                //borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Reports', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _rangeChip('This week', ReportRange.thisWeek),
                              _rangeChip('Last 7 days', ReportRange.last7),
                              _rangeChip('Last 2 weeks', ReportRange.last2Weeks),
                            ]),
                          ),
                          const SizedBox(height: 20),
                          Row(children: [
                            StatCard(number: '${r?.held ?? 0}', label: 'APPOINTMENTS HELD', color: AppColors.navy),
                            const SizedBox(width: 10),
                            StatCard(number: '${r?.peopleMet ?? 0}', label: 'PEOPLE MET', color: AppColors.orange),
                            const SizedBox(width: 10),
                            StatCard(number: '${r?.actionPointsDone ?? 0}/${r?.actionPointsTotal ?? 0}', label: 'ACTIONS CLOSED', color: AppColors.teal),
                          ]),
                          const SizedBox(height: 20),
                          InReportCard(
                            selected: _selected,
                            onPreview: () {
                              if (_selected == null) return;
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AppointmentPreviewScreen(appointment: _selected!),
                              ));
                            },
                          ),
                          const SizedBox(height: 20),
                          if (r != null)
                            ...r.appointments.map((a) => AppointmentListTile(
                                  appointment: a,
                                  selected: _selected?.id == a.id,
                                  onTap: () => setState(() => _selected = a),
                                )),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 2) return;
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: () => Navigator.pushNamed(context, '/new-appointment'),
      ),
    );
  }
}