import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_utils.dart';

class ActionPointsTrackerScreen extends StatefulWidget {
  const ActionPointsTrackerScreen({super.key});

  @override
  State<ActionPointsTrackerScreen> createState() => _ActionPointsTrackerScreenState();
}

class ActionPoint {
  final int id;
  final String description;
  final String? owner;
  final DateTime? dueDate;
  final String status;
  final String appointmentTitle;
  final int appointmentId;
  final String? completedBy;
  final DateTime? completedAt;

  ActionPoint({
    required this.id,
    required this.description,
    this.owner,
    this.dueDate,
    required this.status,
    required this.appointmentTitle,
    required this.appointmentId,
    this.completedBy,
    this.completedAt,
  });
}

enum ActionPointFilter { pending, done, all }
enum SortOption { dueDate, meeting }

class _ActionPointsTrackerScreenState extends State<ActionPointsTrackerScreen> {
  ActionPointFilter _filter = ActionPointFilter.pending;
  SortOption _sortBy = SortOption.dueDate;
  late List<ActionPoint> _allActionPoints = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActionPoints();
  }

  Future<void> _loadActionPoints() async {
    setState(() => _loading = true);
    // TODO: Replace with actual API call
    // For now, using mock data
    _allActionPoints = [
      ActionPoint(
        id: 1,
        description: 'Send revised POSCAFF quote to Hotel Rostows',
        owner: 'You',
        dueDate: DateTime(2026, 7, 7),
        status: 'pending',
        appointmentTitle: 'Legacy Motors — progress review',
        appointmentId: 1,
      ),
      ActionPoint(
        id: 2,
        description: 'Send milestone-2 invoice',
        owner: 'Abraham K.',
        dueDate: DateTime(2026, 7, 11),
        status: 'pending',
        appointmentTitle: 'Legacy Motors — progress review',
        appointmentId: 1,
      ),
      ActionPoint(
        id: 3,
        description: 'Add SMS alert to job-card module spec',
        owner: 'William A.',
        dueDate: DateTime(2026, 7, 14),
        status: 'pending',
        appointmentTitle: 'Legacy Motors — progress review',
        appointmentId: 1,
      ),
      ActionPoint(
        id: 4,
        description: 'Email NAFRRI inception minutes',
        owner: 'Joan N.',
        dueDate: DateTime(2026, 7, 8),
        status: 'done',
        appointmentTitle: 'BNI leadership check-in',
        appointmentId: 2,
        completedBy: 'Joan N.',
        completedAt: DateTime(2026, 7, 8),
      ),
    ];
    setState(() => _loading = false);
  }

  List<ActionPoint> get _filteredActionPoints {
    List<ActionPoint> filtered = _allActionPoints;

    // Filter by status
    if (_filter == ActionPointFilter.pending) {
      filtered = filtered.where((ap) => ap.status == 'pending').toList();
    } else if (_filter == ActionPointFilter.done) {
      filtered = filtered.where((ap) => ap.status == 'done').toList();
    }

    // Sort
    if (_sortBy == SortOption.dueDate) {
      filtered.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    } else {
      filtered.sort((a, b) => a.appointmentTitle.compareTo(b.appointmentTitle));
    }

    return filtered;
  }

  bool _isOverdue(DateTime? dueDate) {
    if (dueDate == null) return false;
    return dueDate.isBefore(DateTime.now());
  }

  void _toggleActionPoint(int index) {
    final ap = _filteredActionPoints[index];
    // TODO: Call API to update status
    AppTheme.showTopSnackBar(context, 'Marked as ${ap.status == "done" ? "pending" : "done"}');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredActionPoints;
    final isOverdueVisible =
        filtered.any((ap) => ap.status == 'pending' && _isOverdue(ap.dueDate));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Action Points'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton(
              icon: const Icon(Icons.sort),
              onSelected: (SortOption value) {
                setState(() => _sortBy = value);
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: SortOption.dueDate,
                  child: Text('Sort by due date'),
                ),
                const PopupMenuItem(
                  value: SortOption.meeting,
                  child: Text('Sort by meeting'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            )
          : Column(
              children: [
                // Filter tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildFilterTab('Pending', ActionPointFilter.pending),
                      const SizedBox(width: 8),
                      _buildFilterTab('Done', ActionPointFilter.done),
                      const SizedBox(width: 8),
                      _buildFilterTab('All', ActionPointFilter.all),
                    ],
                  ),
                ),
                // Overdue indicator
                if (isOverdueVisible)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.red, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'You have overdue action points',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Action points list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No action points',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final ap = filtered[index];
                            final isOverdue = _isOverdue(ap.dueDate);
                            final isLastItem = index == filtered.length - 1;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: isLastItem ? 100 : 12,
                              ),
                              child: GestureDetector(
                                onTap: ap.status == 'pending'
                                    ? () => _toggleActionPoint(index)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardWhite,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isOverdue
                                          ? AppColors.red.withOpacity(0.3)
                                          : const Color(0xFFE2E5EA),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Checkbox(
                                            value: ap.status == 'done',
                                            onChanged: (value) =>
                                                _toggleActionPoint(index),
                                            activeColor: AppColors.green,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ap.description,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: ap.status == 'done'
                                                        ? Colors.grey[400]
                                                        : AppColors.navy,
                                                    decoration: ap.status == 'done'
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'From: ${ap.appointmentTitle}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.teal,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (ap.owner != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF26522)
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                ap.owner!,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFF26522),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (ap.dueDate != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isOverdue
                                                    ? AppColors.red.withOpacity(0.1)
                                                    : const Color(0xFF1AA5AB)
                                                        .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Due ${DateTimeUtils.formatDateFromDateTime(ap.dueDate!)}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: isOverdue
                                                      ? AppColors.red
                                                      : const Color(0xFF1AA5AB),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterTab(String label, ActionPointFilter filter) {
    final isActive = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.navy : const Color(0xFFE2E5EA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}
