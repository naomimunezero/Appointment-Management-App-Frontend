import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/live_refresh.dart';
import '../widgets/bottom_nav_bar.dart';
import 'activity_log_screen.dart';

class ReportsCenterScreen extends StatefulWidget {
  const ReportsCenterScreen({super.key});

  @override
  State<ReportsCenterScreen> createState() => _ReportsCenterScreenState();
}

class _ReportsCenterScreenState extends State<ReportsCenterScreen> {
  static const MethodChannel _reportPdfChannel = MethodChannel(
    'appointment_app/report_pdf',
  );
  static const List<String> _downloadReportSections = [
    'appointments',
    'people',
    'discussions',
    'actions',
  ];

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  bool _exporting = false;
  bool _sharing = false;
  bool _emailing = false;
  Map<String, dynamic>? _reportData;
  bool _permissionChecked = false;
  bool _canExportReports = false;
  bool _canManageAppointments = false;
  int _reportRequestId = 0;

  final List<ReportSection> _reportSections = [
    ReportSection(
      id: 'appointments',
      title: 'Appointment log',
      description: 'Dates, times & status',
      icon: Icons.calendar_today,
    ),
    ReportSection(
      id: 'people',
      title: 'People met',
      description: 'Organisations & contacts',
      icon: Icons.people,
    ),
    ReportSection(
      id: 'discussions_actions',
      title: 'Discussions & Actions',
      description: 'Summaries & action points',
      icon: Icons.assignment,
    ),
    ReportSection(
      id: 'recent_activity',
      title: 'Recent activity',
      description: 'Team activity from the past 30 days',
      icon: Icons.history,
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.navy,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    final today = DateUtils.dateOnly(DateTime.now());
    _startDate = today.subtract(const Duration(days: 29));
    _endDate = today;
    liveRefresh.addListener(_onLiveRefresh);
    _loadPermission();
  }

  @override
  void dispose() {
    liveRefresh.removeListener(_onLiveRefresh);
    super.dispose();
  }

  void _onLiveRefresh() {
    if (_permissionChecked && _canExportReports) {
      _loadReportData();
    }
  }

  Future<void> _loadPermission() async {
    final permissions = await Future.wait([
      ApiService.hasPermission('export_reports'),
      ApiService.hasPermission('manage_appointments'),
    ]);
    if (!mounted) return;
    setState(() {
      _canExportReports = permissions[0];
      _canManageAppointments = permissions[1];
      _permissionChecked = true;
    });
    if (_canExportReports) {
      // Set initial date range if not already set
      if (_startDate == null || _endDate == null) {
        final now = DateTime.now();
        setState(() {
          _startDate = now.subtract(const Duration(days: 29));
          _endDate = now;
        });
      }
      await _loadReportData();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _startDate ?? now.subtract(const Duration(days: 29)),
      end: _endDate ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    if (_startDate == null || _endDate == null) return;

    final requestId = ++_reportRequestId;
    setState(() => _loading = true);
    try {
      final data = await ApiService.getReportData(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        sections: _downloadReportSections,
      );
      if (!mounted || requestId != _reportRequestId) return;
      setState(() {
        _reportData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _reportRequestId) return;
      setState(() => _loading = false);
      AppTheme.showTopSnackBar(context, 'Could not load report data: $e');
    }
  }

  Future<void> _exportCombinedPdf() async {
    if (_startDate == null || _endDate == null) {
      AppTheme.showTopSnackBar(context, 'Please select a date range first');
      return;
    }

    setState(() => _exporting = true);
    try {
      final bytes = await ApiService.exportReportPdf(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        sections: _downloadReportSections,
      );
      if (!mounted) return;
      final filename =
          'combined-report-${DateFormat('yyyyMMdd').format(_startDate!)}-${DateFormat('yyyyMMdd').format(_endDate!)}.pdf';
      if (defaultTargetPlatform == TargetPlatform.android) {
        final uri = await _savePdfToDownloads(bytes, filename);
        if (!mounted) return;
        AppTheme.showTopSnackBar(
          context,
          'PDF saved to Downloads.',
          actionLabel: 'OPEN',
          onAction: () => _openSavedPdf(uri),
        );
      } else {
        await _openPdfShareSheet(bytes, filename, 'Combined Report');
      }
    } catch (e) {
      if (!mounted) return;
      AppTheme.showTopSnackBar(context, 'Could not export PDF: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    if (_startDate == null || _endDate == null) {
      AppTheme.showTopSnackBar(context, 'Please select a date range first');
      return;
    }

    setState(() => _sharing = true);
    try {
      final bytes = await ApiService.exportReportPdf(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        sections: _downloadReportSections,
      );
      if (!mounted) return;
      final filename =
          'combined-report-${DateFormat('yyyyMMdd').format(_startDate!)}-${DateFormat('yyyyMMdd').format(_endDate!)}.pdf';
      if (defaultTargetPlatform == TargetPlatform.android) {
        final uri = await _savePdfToDownloads(bytes, filename);
        await _reportPdfChannel.invokeMethod<void>('sharePdfToApp', {
          'uri': uri,
          'target': 'whatsapp',
        });
      } else {
        await _openPdfShareSheet(bytes, filename, 'Combined Report');
      }
    } catch (e) {
      if (!mounted) return;
      AppTheme.showTopSnackBar(context, 'Could not share: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _sendEmail() async {
    if (_startDate == null || _endDate == null) {
      AppTheme.showTopSnackBar(context, 'Please select a date range first');
      return;
    }

    String? recipient;
    if (defaultTargetPlatform == TargetPlatform.android) {
      recipient = await showDialog<String>(
        context: context,
        builder: (_) => const _ReportRecipientDialog(),
      );
      if (recipient == null || recipient.isEmpty) return;
    }

    setState(() => _emailing = true);
    try {
      final bytes = await ApiService.exportReportPdf(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        sections: _downloadReportSections,
      );
      if (!mounted) return;
      final filename =
          'combined-report-${DateFormat('yyyyMMdd').format(_startDate!)}-${DateFormat('yyyyMMdd').format(_endDate!)}.pdf';
      if (defaultTargetPlatform == TargetPlatform.android) {
        final uri = await _savePdfToDownloads(bytes, filename);
        if (!mounted) return;
        setState(() => _emailing = false);
        await _reportPdfChannel.invokeMethod<void>('sharePdfToApp', {
          'uri': uri,
          'target': 'gmail',
          'recipient': recipient,
        });
      } else {
        await _openPdfShareSheet(bytes, filename, 'Combined Report');
      }
    } catch (e) {
      if (!mounted) return;
      AppTheme.showTopSnackBar(context, 'Could not send email: $e');
    } finally {
      if (mounted && _emailing) setState(() => _emailing = false);
    }
  }

  Future<String> _savePdfToDownloads(List<int> bytes, String filename) async {
    final uri = await _reportPdfChannel.invokeMethod<String>(
      'savePdfToDownloads',
      {'bytes': Uint8List.fromList(bytes), 'filename': filename},
    );
    if (uri == null || uri.isEmpty) {
      throw StateError('The PDF was not saved to Downloads.');
    }
    return uri;
  }

  Future<void> _openSavedPdf(String uri) async {
    try {
      await _reportPdfChannel.invokeMethod<void>('openPdf', {'uri': uri});
    } catch (e) {
      if (!mounted) return;
      AppTheme.showTopSnackBar(
        context,
        'Could not open the PDF. It is saved in Downloads. $e',
      );
    }
  }

  Future<void> _openPdfShareSheet(
    List<int> bytes,
    String filename,
    String subject,
  ) async {
    await Share.shareXFiles([
      XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'application/pdf',
        name: filename,
      ),
    ], subject: subject);
  }

  void _openReportSection(ReportSection section) {
    if (section.id == 'recent_activity') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const ActivityLogScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          section: section,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_canExportReports) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: const Center(
          child: Text('You do not have permission to view reports.'),
        ),
      );
    }

    final counts = _reportData?['counts'] ?? {};
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
        title: const Text(
          'Reports',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReportData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Range Selector
                InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SELECT PERIOD',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _startDate != null && _endDate != null
                                  ? '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM yyyy').format(_endDate!)}'
                                  : 'Select date range',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.calendar_today, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),

                // Summary Cards
                if (_reportData != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          number: '${counts['meetings_held'] ?? 0}',
                          label: 'APPOINTMENTS\nHELD',
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          number: '${counts['people_met'] ?? 0}',
                          label: 'PEOPLE MET',
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          number: '${counts['actions_closed'] ?? 0}',
                          label: 'ACTIONS\nCLOSED',
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // In This Report Section
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IN THIS REPORT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._reportSections.map(
                        (section) => _ReportSectionButton(
                          section: section,
                          onTap: () => _openReportSection(section),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Combined Report Actions
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'COMBINED REPORT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _exporting ? null : _exportCombinedPdf,
                        icon: _exporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _sharing ? null : _shareWhatsApp,
                        icon: _sharing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.share),
                        label: const Text('Share on WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _emailing ? null : _sendEmail,
                        icon: _emailing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.email_outlined),
                        label: const Text('Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.navy),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        onAddTap: _canManageAppointments
            ? () => Navigator.pushNamed(context, '/new-appointment')
            : null,
        showReports: _canExportReports,
      ),
    );
  }
}

class _ReportRecipientDialog extends StatefulWidget {
  const _ReportRecipientDialog();

  @override
  State<_ReportRecipientDialog> createState() => _ReportRecipientDialogState();
}

class _ReportRecipientDialogState extends State<_ReportRecipientDialog> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Email Report'),
      content: TextField(
        controller: _emailController,
        decoration: const InputDecoration(
          labelText: 'Recipient email',
          hintText: 'email@example.com',
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_emailController.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String number;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.number,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportSectionButton extends StatelessWidget {
  final ReportSection section;
  final VoidCallback onTap;

  const _ReportSectionButton({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(section.icon, size: 20, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    section.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class ReportSection {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  ReportSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class ReportDetailScreen extends StatefulWidget {
  final ReportSection section;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReportDetailScreen({
    super.key,
    required this.section,
    this.startDate,
    this.endDate,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  Map<String, dynamic>? _reportData;
  final Set<String> _expandedAppointmentIds = {};

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    if (_startDate != null && _endDate != null) {
      _loadReportData();
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _startDate ?? now.subtract(const Duration(days: 29)),
      end: _endDate ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.navy,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadReportData();
    }
  }

  Future<void> _resetToDefaultPeriod() async {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _startDate = today.subtract(const Duration(days: 29));
      _endDate = today;
    });
    await _loadReportData();
  }

  Future<void> _loadReportData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _loading = true);
    try {
      List<String> sections;
      if (widget.section.id == 'discussions_actions') {
        sections = ['appointments', 'discussions', 'actions'];
      } else {
        sections = widget.section.id == 'appointments'
            ? ['appointments']
            : ['appointments', widget.section.id];
      }
      final data = await ApiService.getReportData(
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        sections: sections,
      );
      if (!mounted) return;
      setState(() {
        _reportData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppTheme.showTopSnackBar(context, 'Could not load report data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: AppColors.navy,
          statusBarIconBrightness: Brightness.light,
        ),
        title: Text(widget.section.title),
      ),
      body: RefreshIndicator(
        onRefresh: _resetToDefaultPeriod,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Range Selector
              InkWell(
                onTap: _selectDateRange,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECT PERIOD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM yyyy').format(_endDate!)}'
                                : 'Select date range',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.calendar_today, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Report Preview
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_reportData != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                      const Text(
                        'REPORT PREVIEW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReportPreview(),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Select a date range to preview the report'),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    switch (widget.section.id) {
      case 'appointments':
        final appointments = _reportData?['appointments'] ?? [];
        return _buildAppointmentsTable(appointments);
      case 'people':
        final people = _reportData?['people'] ?? [];
        return _buildPeopleTable(_peopleWithAppointments(people));
      case 'discussions_actions':
        return _buildDiscussionsActionsList();
      default:
        return const Text('No data available');
    }
  }

  List<Map<String, dynamic>> _peopleWithAppointments(List<dynamic> people) {
    final rows = <Map<String, dynamic>>[];
    final appointmentList = _appointments;

    for (final rawPerson in people.whereType<Map>()) {
      final person = _asStringMap(rawPerson);
      final linkedAppointment = _relatedAppointment(person);
      if (linkedAppointment != null) {
        rows.add({...person, 'appointment': linkedAppointment});
        continue;
      }

      final relatedAppointments =
          person['appointments'] ??
          person['meetings'] ??
          person['appointments_list'];

      if (relatedAppointments is List && relatedAppointments.isNotEmpty) {
        for (final rawAppointment in relatedAppointments) {
          if (rawAppointment is Map) {
            rows.add({...person, 'appointment': _asStringMap(rawAppointment)});
          } else if (_appointmentById(rawAppointment) case final appointment?) {
            rows.add({...person, 'appointment': appointment});
          } else {
            rows.add({...person, 'appointment_id': rawAppointment});
          }
        }
        continue;
      }

      final embeddedAppointment = person['appointment'];
      if (embeddedAppointment is Map) {
        rows.add({...person, 'appointment': _asStringMap(embeddedAppointment)});
        continue;
      }

      final linkedAppointments = appointmentList
          .where((appointment) => _appointmentHasPerson(appointment, person))
          .toList();
      if (linkedAppointments.isNotEmpty) {
        for (final appointment in linkedAppointments) {
          rows.add({...person, 'appointment': appointment});
        }
      } else {
        rows.add(person);
      }
    }

    for (final appointment in appointmentList) {
      for (final attendee in _attendeesForAppointment(appointment)) {
        final attendeeMap = attendee is Map
            ? _asStringMap(attendee)
            : <String, dynamic>{'name': attendee};
        final name = _firstText(attendeeMap, [
          'name',
          'full_name',
          'person_name',
          'contact_name',
          'attendee_name',
        ]);
        final email = _firstText(attendeeMap, [
          'email',
          'person_email',
          'contact_email',
        ]);
        final personId =
            attendeeMap['id'] ??
            attendeeMap['person_id'] ??
            attendeeMap['contact_id'] ??
            attendeeMap['attendee_id'];

        final exists = rows.any((row) {
          final rowId =
              row['id'] ??
              row['person_id'] ??
              row['contact_id'] ??
              row['attendee_id'];
          if (personId != null && rowId != null) {
            return personId.toString() == rowId.toString() &&
                _relatedAppointment(row)?['id']?.toString() ==
                    appointment['id']?.toString();
          }
          final rowName = _firstText(row, [
            'name',
            'full_name',
            'person_name',
            'contact_name',
            'attendee_name',
          ]);
          final rowEmail = _firstText(row, [
            'email',
            'person_email',
            'contact_email',
          ]);
          return ((name.isNotEmpty && name == rowName) ||
                  (email.isNotEmpty && email == rowEmail)) &&
              _relatedAppointment(row)?['id']?.toString() ==
                  appointment['id']?.toString();
        });
        if (!exists) {
          rows.add({
            ...attendeeMap,
            'name': name,
            'email': email,
            'appointment': appointment,
          });
        }
      }
    }

    return rows.where((row) {
      final appointment = _relatedAppointment(row);
      return appointment != null &&
          _appointmentDate(row).trim().isNotEmpty &&
          _appointmentPurpose(row).trim().isNotEmpty &&
          _firstText(row, [
            'name',
            'full_name',
            'person_name',
            'contact_name',
            'attendee_name',
            'email',
            'person_email',
            'contact_email',
          ]).isNotEmpty;
    }).toList();
  }

  List<dynamic> _attendeesForAppointment(Map<String, dynamic> appointment) {
    for (final value in [
      appointment['people_met'],
      appointment['people'],
      appointment['attendees'],
      appointment['attendee_details'],
      appointment['people_met_details'],
      appointment['people_met_names'],
    ]) {
      if (value is List) return value;
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[,;\n]'))
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList();
      }
    }
    final personToMeet = appointment['person_to_meet'];
    return personToMeet is String && personToMeet.trim().isNotEmpty
        ? [personToMeet]
        : const [];
  }

  bool _appointmentHasPerson(
    Map<String, dynamic> appointment,
    Map<String, dynamic> person,
  ) {
    List? attendees;
    for (final value in [
      appointment['people_met'],
      appointment['people'],
      appointment['attendees'],
      appointment['attendee_details'],
      appointment['people_met_details'],
      appointment['people_met_names'],
      appointment['person_to_meet'] == null
          ? null
          : [appointment['person_to_meet']],
    ]) {
      if (value is List) {
        attendees = value;
        break;
      }
    }
    if (attendees == null) return false;

    final personId =
        person['id'] ??
        person['person_id'] ??
        person['contact_id'] ??
        person['attendee_id'];
    final personName = _firstText(person, [
      'name',
      'full_name',
      'person_name',
      'contact_name',
      'attendee_name',
    ]).toLowerCase();
    final personEmail = _firstText(person, [
      'email',
      'person_email',
      'contact_email',
    ]).toLowerCase();

    return attendees.any((attendee) {
      if (attendee is Map) {
        final item = _asStringMap(attendee);
        final attendeeId =
            item['id'] ??
            item['person_id'] ??
            item['contact_id'] ??
            item['attendee_id'];
        if (personId != null &&
            attendeeId != null &&
            personId.toString() == attendeeId.toString()) {
          return true;
        }
        final name = _firstText(item, [
          'name',
          'full_name',
          'person_name',
          'contact_name',
          'attendee_name',
        ]).toLowerCase();
        final email = _firstText(item, [
          'email',
          'person_email',
          'contact_email',
        ]).toLowerCase();
        return (personName.isNotEmpty && personName == name) ||
            (personEmail.isNotEmpty && personEmail == email);
      }
      return personName.isNotEmpty &&
          attendee.toString().trim().toLowerCase() == personName;
    });
  }

  String _firstText(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  List<Map<String, dynamic>> _discussionRows() {
    final rawDiscussions = _reportData?['discussions'];
    final rows = rawDiscussions is List
        ? rawDiscussions.whereType<Map>().map(_asStringMap).toList()
        : <Map<String, dynamic>>[];

    for (final appointment in _appointments) {
      final notes =
          appointment['discussion_notes'] ??
          appointment['discussion_summary'] ??
          appointment['summary'];
      if (notes == null || notes.toString().trim().isEmpty) continue;

      final appointmentId = appointment['id']?.toString();
      final alreadyIncluded = rows.any(
        (row) => _relatedAppointment(row)?['id']?.toString() == appointmentId,
      );
      if (!alreadyIncluded) {
        rows.add({'summary': notes, 'appointment': appointment});
      }
    }

    return rows.map(_attachAppointment).toList();
  }

  List<Map<String, dynamic>> _actionRows() {
    final rawActions =
        _reportData?['actions'] ?? _reportData?['action_points'];
    final rows = rawActions is List
        ? rawActions.whereType<Map>().map(_asStringMap).toList()
        : <Map<String, dynamic>>[];

    for (final appointment in _appointments) {
      final appointmentActions = appointment['action_points'];
      if (appointmentActions is! List) continue;

      for (final rawAction in appointmentActions.whereType<Map>()) {
        final action = _asStringMap(rawAction);
        final actionId = action['id']?.toString();
        final description = action['description']?.toString().trim();
        final existingIndex = rows.indexWhere((row) {
          final rowId = row['id']?.toString();
          if (actionId != null && rowId != null) return actionId == rowId;

          final sameDescription =
              description?.isNotEmpty == true &&
              row['description']?.toString().trim() == description;
          if (!sameDescription) return false;
          final linked = _relatedAppointment(row);
          return linked == null ||
              linked['id']?.toString() == appointment['id']?.toString();
        });

        final linkedAction = {...action, 'appointment': appointment};
        if (existingIndex == -1) {
          rows.add(linkedAction);
        } else {
          rows[existingIndex] = {...rows[existingIndex], ...linkedAction};
        }
      }
    }

    return rows.map(_attachAppointment).toList();
  }

  List<Map<String, dynamic>> _combinedDiscussionActionRows() {
    final discussions = _discussionRows();
    final actions = _actionRows();
    final rows = <Map<String, dynamic>>[];

    for (final discussion in discussions) {
      final appointment = _relatedAppointment(discussion);
      final appointmentId = appointment?['id']?.toString();
      final discussionId = _discussionId(discussion, includeOwnId: true);
      final discussionText =
          (discussion['summary'] ??
                  discussion['discussion_notes'] ??
                  discussion['notes'] ??
                  discussion['description'] ??
                  '')
              .toString();
      final relatedActions = <String>{};

      for (var index = 0; index < actions.length; index++) {
        final action = actions[index];
        final actionAppointment = _relatedAppointment(action);
        final belongsToAppointment =
            appointmentId != null &&
            actionAppointment?['id']?.toString() == appointmentId;
        final actionDiscussionId = _discussionId(action);
        final belongsToDiscussion =
            discussionId != null && actionDiscussionId == discussionId;
        if (belongsToAppointment || belongsToDiscussion) {
          _addActionDescription(relatedActions, action);
        }
      }

      _addEmbeddedActionDescriptions(relatedActions, discussion);
      if (appointment != null) {
        _addEmbeddedActionDescriptions(relatedActions, appointment);
      }

      rows.add({
        'discussion': discussionText,
        'action_point': relatedActions.join('\n'),
        'appointment': appointment,
        'held_at': _heldDateTime(discussion, appointment),
      });
    }

    return rows.where((row) {
      final appointment = row['appointment'];
      return row['discussion']?.toString().trim().isNotEmpty == true &&
          appointment is Map &&
          _appointmentPurpose(_asStringMap(appointment)).trim().isNotEmpty &&
          row['held_at']?.toString().trim().isNotEmpty == true;
    }).toList();
  }

  String? _discussionId(
    Map<String, dynamic> item, {
    bool includeOwnId = false,
  }) {
    final id =
        item['discussion_id'] ??
        item['discussionId'] ??
        (includeOwnId ? item['id'] : null);
    return id?.toString();
  }

  void _addEmbeddedActionDescriptions(
    Set<String> descriptions,
    Map<String, dynamic> source,
  ) {
    for (final key in [
      'action_points',
      'actionPoints',
      'actions',
      'action_point',
      'actionPoint',
    ]) {
      final value = source[key];
      if (value is List) {
        for (final action in value) {
          _addActionDescription(descriptions, action);
        }
      } else if (value != null) {
        _addActionDescription(descriptions, value);
      }
    }
  }

  void _addActionDescription(Set<String> descriptions, dynamic action) {
    final description = action is Map
        ? _firstText(_asStringMap(action), [
            'description',
            'action_point',
            'actionPoint',
            'action',
            'title',
            'text',
          ])
        : action.toString().trim();
    if (description.isNotEmpty) descriptions.add(description);
  }

  String _heldDateTime(
    Map<String, dynamic> item,
    Map<String, dynamic>? appointment,
  ) {
    return (appointment?['held_at'] ??
            appointment?['heldAt'] ??
            appointment?['held_on'] ??
            item['held_at'] ??
            item['heldAt'] ??
            item['held_on'] ??
            appointment?['scheduled_date_time'] ??
            appointment?['appointment_date'] ??
            appointment?['date'] ??
            item['appointment_date'] ??
            item['meeting_date'] ??
            item['date'] ??
            '')
        .toString();
  }

  Map<String, dynamic> _attachAppointment(Map<String, dynamic> row) {
    final appointment = _relatedAppointment(row);
    return appointment == null ? row : {...row, 'appointment': appointment};
  }

  Map<String, dynamic>? _relatedAppointment(Map<String, dynamic> item) {
    for (final key in [
      'appointment',
      'meeting',
      'appointment_details',
      'meeting_details',
    ]) {
      final embedded = item[key];
      if (embedded is Map) return _asStringMap(embedded);
    }

    final id =
        item['appointment_id'] ??
        item['appointmentId'] ??
        item['meeting_id'] ??
        item['meetingId'] ??
        item['parent_appointment_id'] ??
        item['parent_id'] ??
        item['appointment'];
    final linked = _appointmentById(id);
    if (linked != null) return linked;

    final purpose =
        item['appointment_purpose'] ??
        item['appointment_title'] ??
        item['purpose'];
    if (purpose != null) {
      final normalizedPurpose = purpose.toString().trim().toLowerCase();
      for (final appointment in _appointments) {
        if (_purposeOf(appointment).trim().toLowerCase() == normalizedPurpose) {
          return appointment;
        }
      }
    }

    if (item['appointment_purpose'] != null ||
        item['purpose'] != null ||
        item['appointment_date'] != null ||
        item['scheduled_date_time'] != null) {
      return item;
    }
    return null;
  }

  List<Map<String, dynamic>> get _appointments {
    final appointments = _reportData?['appointments'];
    if (appointments is! List) return [];
    return appointments.whereType<Map>().map(_asStringMap).toList();
  }

  Map<String, dynamic>? _appointmentById(dynamic id) {
    if (id == null || id is Map || id is List) return null;
    for (final appointment in _appointments) {
      if (appointment['id']?.toString() == id.toString()) {
        return appointment;
      }
    }
    return null;
  }

  String _purposeOf(Map<String, dynamic> appointment) {
    return (appointment['purpose'] ??
            appointment['appointment_purpose'] ??
            appointment['title'] ??
            '')
        .toString();
  }

  String _appointmentPurpose(Map<String, dynamic> item) {
    final appointment = _relatedAppointment(item);
    return ((appointment == null ? null : _purposeOf(appointment)) ??
            item['appointment_purpose'] ??
            item['appointment_title'] ??
            item['purpose'] ??
            '')
        .toString();
  }

  String _appointmentDate(Map<String, dynamic> item) {
    final appointment = _relatedAppointment(item);
    return (appointment?['date'] ??
            appointment?['held_at'] ??
            appointment?['scheduled_date_time'] ??
            appointment?['appointment_date'] ??
            appointment?['heldAt'] ??
            item['appointment_date'] ??
            item['meeting_date'] ??
            item['date'] ??
            '')
        .toString();
  }

  static Map<String, dynamic> _asStringMap(Map value) =>
      Map<String, dynamic>.from(value);

  Widget _buildAppointmentsTable(List<dynamic> appointments) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 8,
          headingRowColor: WidgetStateProperty.all(
            AppColors.navy.withValues(alpha: 0.1),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Appointment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Scheduled Date & Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Held At',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Duration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: appointments.map<DataRow>((apt) {
            return DataRow(
              cells: [
                DataCell(Text(apt['purpose']?.toString() ?? '')),
                DataCell(Text(apt['scheduled_date_time']?.toString() ?? '')),
                DataCell(Text(apt['held_at']?.toString() ?? 'N/A')),
                DataCell(Text('${apt['duration'] ?? 0} min')),
                DataCell(Text(apt['location']?.toString() ?? '')),
                DataCell(Text(apt['status']?.toString() ?? '')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPeopleTable(List<dynamic> people) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 8,
          headingRowColor: WidgetStateProperty.all(
            AppColors.navy.withValues(alpha: 0.1),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'People Met',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Appointment',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: people.map<DataRow>((person) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    _firstText(person, [
                      'name',
                      'full_name',
                      'person_name',
                      'contact_name',
                      'attendee_name',
                    ]),
                  ),
                ),
                DataCell(Text(_appointmentPurpose(person))),
                DataCell(Text(_appointmentDate(person))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDiscussionsActionsList() {
    final appointments = _appointments;
    if (appointments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No appointments found for this period.'),
      );
    }

    final discussions = _discussionRows();
    final actions = _actionRows();
    return Column(
      children: appointments.map((appointment) {
        final id = appointment['id']?.toString();
        final isExpanded = id != null && _expandedAppointmentIds.contains(id);
        final appointmentDiscussions = discussions.where((item) =>
            id != null && _relatedAppointment(item)?['id']?.toString() == id).toList();
        final discussionIds = appointmentDiscussions
            .map((item) => _discussionId(item, includeOwnId: true))
            .whereType<String>()
            .toSet();
        final appointmentActions = actions.where((item) =>
            (id != null && _relatedAppointment(item)?['id']?.toString() == id) ||
            (discussionIds.isNotEmpty &&
                discussionIds.contains(_discussionId(item)))).toList();
        final discussionPreviews = appointmentDiscussions.map((item) =>
            _firstText(item, ['summary', 'discussion_notes', 'notes', 'description'])).where((s) => s.isNotEmpty).toList();
        final actionPreviews = appointmentActions.map((item) =>
            _firstText(item, ['description', 'action_point', 'actionPoint', 'action', 'title', 'text'])).where((s) => s.isNotEmpty).toSet().toList();
        // Some APIs return notes/actions directly on the appointment.
        if (discussionPreviews.isEmpty) {
          final notes = _firstText(appointment, ['discussion_notes', 'discussion_summary', 'summary']);
          if (notes.isNotEmpty) discussionPreviews.add(notes);
        }
        if (actionPreviews.isEmpty) {
          final embedded = <String>{};
          _addEmbeddedActionDescriptions(embedded, appointment);
          actionPreviews.addAll(embedded);
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_appointmentPurpose(appointment).isEmpty ? 'Appointment' : _appointmentPurpose(appointment),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text(_heldDateTime(appointment, appointment), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 12),
            _reportPreviewRow(
              'Discussion',
              isExpanded ? discussionPreviews : discussionPreviews.take(1).toList(),
              expanded: isExpanded,
            ),
            const SizedBox(height: 8),
            _reportPreviewRow(
              'Action point',
              isExpanded ? actionPreviews : actionPreviews.take(1).toList(),
              expanded: isExpanded,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: id == null
                    ? null
                    : () => setState(() {
                        if (isExpanded) {
                          _expandedAppointmentIds.remove(id);
                        } else {
                          _expandedAppointmentIds.add(id);
                        }
                      }),
                child: Text(isExpanded ? 'Hide details' : 'View details'),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _reportPreviewRow(
    String label,
    List<String> items, {
    required bool expanded,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 94, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(
        child: items.isEmpty
            ? const Text('None recorded')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    item,
                    maxLines: expanded ? null : 2,
                    overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  ),
                )).toList(),
              ),
      ),
    ]);
  }

}
