import 'package:appointment_app/services/attendee_history_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/field_label.dart';
import '../utils/validators.dart';

class NewAppointmentScreen extends StatefulWidget {
  const NewAppointmentScreen({super.key});

  @override
  State<NewAppointmentScreen> createState() => _NewAppointmentScreenState();
}

class _NewAppointmentScreenState extends State<NewAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _emailController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _locationController = TextEditingController();
  final _reminderMinutesController = TextEditingController();
  final _nameController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _durationUnit = 'min';
  String _locationType = 'physical';
  String? _zoomLink;
  String _reminderUnit = 'min'; 


  int? _durationInMinutes() {
    final raw = int.tryParse(_durationController.text);
    if (raw == null) return null;
    return _durationUnit == 'hr' ? raw * 60 : raw;
  }

  List<Map<String, String>> _attendees = [];
  List<Map<String, dynamic>> _reminders = [
    {'minutes_before': 300},
    {'minutes_before': 30},
  ];

  bool _loading = false;
  bool _checkingConflict = false;
  String? _conflictError;
  List<dynamic> _searchResults = [];
  bool _showSearchResults = false;

  @override
  void dispose() {
    _purposeController.dispose();
    _emailController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    _reminderMinutesController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _selectedDate = picked);
      setState(() => _conflictError = null);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
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
      setState(() => _selectedTime = picked);
      setState(() => _conflictError = null);
    }
  }

  Future<void> _checkForConflicts() async {
    if (_selectedDate == null || _selectedTime == null) return;

    setState(() => _checkingConflict = true);
    setState(() => _conflictError = null);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeStr = _formatTime(_selectedTime!);
    final durationMinutes = _durationInMinutes() ?? 60;

    final result = await ApiService.checkTimeConflict(dateStr, timeStr, durationMinutes);

    setState(() => _checkingConflict = false);

    if (result['success'] == true && result['conflict'] == true) {
      final conflicting = result['conflictingAppointment'];
      setState(() => _conflictError = 
          'Overlaps with "${conflicting['purpose']}" (${conflicting['start_time']} – ${conflicting['end_time']}). Choose a free slot.');
    } else if (result['success'] == true) {
      setState(() => _conflictError = null);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _showSearchResults = false);
      return;
    }

    final backendResults = await ApiService.searchUsers(query);
    final historyResults = await AttendeeHistoryService.search(query);

    final combined = [...backendResults];
    for (final h in historyResults) {
      final alreadyThere = combined.any((r) => r['email'] == h['email']);
      if (!alreadyThere) combined.add(h);
    }

    setState(() {
      _searchResults = combined;
      _showSearchResults = true;
    });
  }

  void _addAttendeeEmail(String email, {String? name}) {
    final trimmedEmail = email.trim();
    if (isValidEmail(trimmedEmail) && !_attendees.any((a) => a['email'] == trimmedEmail)) {
      final resolvedName = name?.trim().isNotEmpty == true ? name!.trim() : trimmedEmail.split('@').first;
      setState(() {
        _attendees.add({'name': resolvedName, 'email': trimmedEmail});
        _emailController.clear();
        _showSearchResults = false;
      });
      AttendeeHistoryService.save(resolvedName, trimmedEmail);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
    }
  }

  void _removeAttendeeEmail(String email) {
    setState(() => _attendees.removeWhere((a) => a['email'] == email));
  }

  void _showAddReminderDialog() {
    _reminderMinutesController.clear();
    _reminderUnit = 'min';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reminderMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 30',
                    labelText: 'Remind me',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _reminderUnit,
                  items: const [
                    DropdownMenuItem(value: 'min', child: Text('min')),
                    DropdownMenuItem(value: 'hr', child: Text('hr')),
                    DropdownMenuItem(value: 'day', child: Text('day')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => _reminderUnit = value);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(_reminderMinutesController.text);
                if (val != null && val > 0) {
                  final multiplier = _reminderUnit == 'day'
                      ? 1440
                      : _reminderUnit == 'hr'
                          ? 60
                          : 1;
                  setState(() {
                    _reminders.add({'minutes_before': val * multiplier});
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeReminder(int index) {
    if (_reminders.length > 1) {
      setState(() => _reminders.removeAt(index));
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time')),
      );
      return;
    }
    
    final durationMinutes = _durationInMinutes();
    if (durationMinutes == null || durationMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum duration is 15 minutes')),
      );
      return;
    }
    
    if (_conflictError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please resolve time conflicts')),
      );
      return;
    }
    
    if (_locationType == 'physical' && _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }
    
    if (_locationType == 'online' && (_zoomLink == null || _zoomLink!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a Zoom link')),
      );
      return;
    }

    setState(() => _loading = true);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final timeStr = _formatTime(_selectedTime!);

    final result = await ApiService.createAppointment(
      purpose: _purposeController.text.trim(),
      date: dateStr,
      startTime: timeStr,
      durationMinutes: durationMinutes,
      attendees: _attendees,
      locationType: _locationType,
      location: _locationType == 'physical' ? _locationController.text.trim() : null,
      zoomLink: _locationType == 'online' ? _zoomLink : null,
      reminders: _reminders,
    );

    setState(() => _loading = false);

    if (result['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment created successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to create appointment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedDate != null && 
                    _selectedTime != null && 
                    (_durationInMinutes() ?? 0) >= 15 && 
                    _conflictError == null &&
                    _purposeController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New appointment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PURPOSE / TITLE
                const FieldLabel('PURPOSE / TITLE', required:false),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _purposeController,
                  decoration: InputDecoration(
                    hintText: 'Contract signing — Hotel Rostows',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Purpose is required' : null,
                ),
                const SizedBox(height: 20),

                // DATE AND DURATION ON SAME ROW
                Row(
                  children: [
                    const FieldLabel('DATE', required:false),
                    const SizedBox(width: 30),
                    const FieldLabel('DURATION', required:false),
                  ],
                ),
                
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        readOnly: true,
                        onTap: _selectDate,
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        controller: TextEditingController(
                          text: _selectedDate != null ? DateFormat('d MMM').format(_selectedDate!) : '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '60',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                            onChanged: (_) => _checkForConflicts(),
                            validator: (v) {
                              final raw = int.tryParse(v ?? '');
                              if (raw == null || raw <= 0) return 'Required';
                              final totalMinutes = _durationUnit == 'hr' ? raw * 60 : raw;
                              if (totalMinutes < 15) return 'Min 15 min';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _durationUnit,
                            items: const [
                              DropdownMenuItem(value: 'min', child: Text('min', style: TextStyle(fontSize: 13))),
                              DropdownMenuItem(value: 'hr', child: Text('hr', style: TextStyle(fontSize: 13))),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _durationUnit = value);
                              _checkForConflicts();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
                const SizedBox(height: 20),

                // START TIME
                const FieldLabel('START TIME', required:false),
                const SizedBox(height: 8),
                TextFormField(
                  readOnly: true,
                  onTap: _selectTime,
                  decoration: InputDecoration(
                    hintText: 'Select time',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    suffixIcon: GestureDetector(
                      onTap: _selectTime,
                      child: Icon(
                        Icons.schedule_outlined,
                        size: 20,
                        color: _conflictError != null ? AppColors.red : Colors.grey[600],
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _conflictError != null ? AppColors.red : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: _conflictError != null ? AppColors.red : AppColors.navy,
                      ),
                    ),
                  ),
                  controller: TextEditingController(
                    text: _selectedTime != null ? _selectedTime!.format(context) : '',
                  ),
                  onChanged: (_) => _checkForConflicts(),
                ),

                // CONFLICT ERROR
                if (_conflictError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _conflictError!,
                      style: const TextStyle(color: AppColors.red, fontSize: 13),
                    ),
                  ),

                if (_checkingConflict)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // PERSON(S) TO MEET
                // PERSON(S) TO MEET
                const FieldLabel('PERSON(S) TO MEET', required: false),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Name',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'ronald@nugsoft.com',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.orange),
                                    onPressed: () {
                                      _addAttendeeEmail(_emailController.text, name: _nameController.text);
                                      _nameController.clear();
                                    },
                                  ),
                                ),
                                onChanged: _searchUsers,
                                onFieldSubmitted: (value) {
                                  _addAttendeeEmail(value, name: _nameController.text);
                                  _nameController.clear();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_attendees.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _attendees.map((a) {
                              return Chip(
                                label: Text(a['name'] ?? a['email'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                backgroundColor: AppColors.navy,
                                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onDeleted: () => _removeAttendeeEmail(a['email']!),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                    if (_showSearchResults && _searchResults.isNotEmpty)
                      Positioned(
                        top: 56,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return ListTile(
                                title: Text(user['name'] ?? 'Unknown'),
                                subtitle: Text(user['email']),
                                onTap: () {
                                  _addAttendeeEmail(user['email'], name: user['name']);
                                  _nameController.clear();
                                  setState(() => _showSearchResults = false);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                                
                const SizedBox(height: 20),

                // LOCATION
                const FieldLabel('LOCATION', required:false),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _locationType = 'physical'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _locationType == 'physical' ? AppColors.orange.withOpacity(0.12) : Colors.white,
                            border: Border.all(
                              color: _locationType == 'physical' ? AppColors.orange : Colors.grey.shade300,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Physical',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _locationType == 'physical' ? AppColors.orange : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _locationType = 'online'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _locationType == 'online' ? AppColors.orange.withOpacity(0.12) : Colors.white,
                            border: Border.all(
                              color: _locationType == 'online' ? AppColors.orange : Colors.grey.shade300,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Virtual / Online',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _locationType == 'online' ? AppColors.orange : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_locationType == 'physical')
                  TextFormField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'E.g Nugsoft boardroom, Kyanja',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    validator: (v) => _locationType == 'physical' && (v == null || v.trim().isEmpty)
                        ? 'Location is required'
                        : null,
                  ),
                if (_locationType == 'online')
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Paste/enter the link to the meeting here',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    onChanged: (value) => setState(() => _zoomLink = value),
                    validator: (v) => _locationType == 'online' && (v == null || v.trim().isEmpty)
                        ? 'Zoom link is required'
                        : null,
                  ),
                const SizedBox(height: 20),

                // REMIND ME
                const FieldLabel('REMIND ME', required:false),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(_reminders.length, (index) {
                    final reminder = _reminders[index];
                    final mins = reminder['minutes_before'] as int;
                    String label;
                    if (mins % 1440 == 0 && mins >= 1440) {
                      final days = mins ~/ 1440;
                      label = '$days day${days > 1 ? 's' : ''} before';
                    } else if (mins % 60 == 0 && mins >= 60) {
                      final hrs = mins ~/ 60;
                      label = '$hrs hr${hrs > 1 ? 's' : ''} before';
                    } else {
                      label = '$mins min before';
                    }

                    return GestureDetector(
                      onTap: _reminders.length > 1 ? () => _removeReminder(index) : null,
                      child: Chip(
                        label: Text(label),
                        backgroundColor: AppColors.orange.withOpacity(0.12),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.orange, width: 1.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        deleteIcon: _reminders.length > 1 ? const Icon(Icons.close, size: 16) : null,
                        onDeleted: _reminders.length > 1 ? () => _removeReminder(index) : null,
                      ),
                    );
                  }),
                ),
                if (_reminders.length < 10)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: _showAddReminderDialog,
                      child: const Text(
                        '+ Add reminder',
                        style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                const SizedBox(height: 32),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: canSave && !_loading ? _saveAppointment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      disabledBackgroundColor: AppColors.orange.withOpacity(0.5),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Save appointment',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/diary');
          if (index == 2) Navigator.pushNamed(context, '/reports');
          if (index == 3) return;
        },
        onAddTap: () => Navigator.pushNamed(context, '/new-appointment'),
      ),
    );
  }
}

