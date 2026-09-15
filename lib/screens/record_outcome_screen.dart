import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../utils/date_time_utils.dart';

class RecordOutcomeScreen extends StatefulWidget {
  final int appointmentId;

  const RecordOutcomeScreen({
    super.key,
    required this.appointmentId,
  });

  @override
  State<RecordOutcomeScreen> createState() => _RecordOutcomeScreenState();
}

class ActionPointData {
  String description;
  String? owner;
  DateTime? dueDate;

  ActionPointData({
    required this.description,
    this.owner,
    this.dueDate,
  });
}

class _RecordOutcomeScreenState extends State<RecordOutcomeScreen> {
  late Future<Appointment> _appointmentFuture;
  final _discussionController = TextEditingController();
  late List<String> _attendees = [];
  final List<ActionPointData> _actionPoints = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.navy,
      statusBarIconBrightness: Brightness.light,
    ));
    _appointmentFuture = ApiService.getAppointmentDetails(widget.appointmentId);
  }

  @override
  void dispose() {
    _discussionController.dispose();
    super.dispose();
  }

  void _addAttendee() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add attendee'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter name or email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _attendees.add(controller.text.trim());
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeAttendee(int index) {
    setState(() {
      _attendees.removeAt(index);
    });
  }

  void _addActionPoint() {
    showDialog(
      context: context,
      builder: (context) {
        final descController = TextEditingController();
        String? selectedOwner;
        DateTime? selectedDate;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add action point'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description'),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        hintText: 'What needs to be done?',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Text('Owner'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedOwner,
                      hint: const Text('Select owner'),
                      items: _attendees
                          .map((attendee) => DropdownMenuItem(
                                value: attendee,
                                child: Text(attendee),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedOwner = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Due date'),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate != null
                            ? DateTimeUtils.formatDateFromDateTime(selectedDate!)
                            : 'Pick a date',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (descController.text.trim().isNotEmpty) {
                      setState(() {
                        _actionPoints.add(
                          ActionPointData(
                            description: descController.text.trim(),
                            owner: selectedOwner,
                            dueDate: selectedDate,
                          ),
                        );
                      });
                      Navigator.pop(context);
                      this.setState(() {});
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeActionPoint(int index) {
    setState(() {
      _actionPoints.removeAt(index);
    });
  }

  Future<void> _submitOutcome() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await ApiService.recordAppointmentOutcome(
        widget.appointmentId,
        discussionNotes: _discussionController.text,
        actionPoints: _actionPoints
            .map((ap) => {
                  'description': ap.description,
                  'responsible_person': ap.owner,
                  'due_date': ap.dueDate?.toIso8601String().substring(0, 10),
                  'status': 'pending',
                })
            .toList(),
        attendees: _attendees,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment marked as Held'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to record outcome'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Record Outcome'),
        centerTitle: true,
      ),
      body: FutureBuilder<Appointment>(
        future: _appointmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading appointment',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _appointmentFuture =
                            ApiService.getAppointmentDetails(widget.appointmentId);
                      });
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No appointment data'));
          }

          final appointment = snapshot.data!;

          // Initialize attendees from appointment on first build
          if (_attendees.isEmpty) {
            _attendees = List.from(appointment.attendees);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Appointment Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.purpose,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateTimeUtils.formatDateTime(
                          appointment.appointmentDate,
                          appointment.startTime,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // WHO DID YOU MEET
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'WHO DID YOU MEET',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Color(0xFF666666),
                            ),
                          ),
                          GestureDetector(
                            onTap: _addAttendee,
                            child: const Text(
                              '+ Add',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_attendees.isEmpty)
                        const Text(
                          'No attendees added',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            _attendees.length,
                            (index) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.navy.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.navy.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _attendees[index],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _removeAttendee(index),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFFCCCCCC),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // WHAT WAS DISCUSSED
                Text(
                  'WHAT WAS DISCUSSED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _discussionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Add discussion notes and key points from the meeting...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.navy, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 24),

                // ACTION POINTS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTION POINTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_actionPoints.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Points List
                if (_actionPoints.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E5EA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        _actionPoints.length,
                        (index) {
                          final ap = _actionPoints[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index < _actionPoints.length - 1 ? 12 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ap.description,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (ap.owner != null)
                                            Text(
                                              'Owner: ${ap.owner}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF888888),
                                              ),
                                            ),
                                          if (ap.dueDate != null)
                                            Text(
                                              'Due: ${DateTimeUtils.formatDateFromDateTime(ap.dueDate!)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF888888),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _removeActionPoint(index),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: Color(0xFFCCCCCC),
                                      ),
                                    ),
                                  ],
                                ),
                                if (index < _actionPoints.length - 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Divider(
                                      color: Colors.grey[200],
                                      height: 1,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Add Action Point Button
                OutlinedButton.icon(
                  onPressed: _addActionPoint,
                  icon: const Icon(Icons.add),
                  label: const Text('Add action point'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOutcome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSubmitting ? 'Saving...' : 'Save & mark as held',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
