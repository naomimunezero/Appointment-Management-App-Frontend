import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';

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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _locationType = 'physical';
  String? _zoomLink;

  List<String> _attendeeEmails = [];
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
    final durationMinutes = int.tryParse(_durationController.text) ?? 60;

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

    final results = await ApiService.searchUsers(query);
    setState(() {
      _searchResults = results;
      _showSearchResults = true;
    });
  }

  void _addAttendeeEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (emailRegex.hasMatch(email.trim()) && !_attendeeEmails.contains(email.trim())) {
      setState(() {
        _attendeeEmails.add(email.trim());
        _emailController.clear();
        _showSearchResults = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
    }
  }

  void _removeAttendeeEmail(String email) {
    setState(() => _attendeeEmails.remove(email));
  }

  void _showAddReminderDialog() {
    _reminderMinutesController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Reminder'),
        content: TextField(
          controller: _reminderMinutesController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter minutes before appointment',
            labelText: 'Minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final mins = int.tryParse(_reminderMinutesController.text);
              if (mins != null && mins > 0) {
                setState(() {
                  _reminders.add({'minutes_before': mins});
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
    
    final durationMinutes = int.tryParse(_durationController.text);
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
      attendeeEmails: _attendeeEmails,
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
                    (int.tryParse(_durationController.text) ?? 0) >= 15 && 
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
                const _FieldLabel('PURPOSE / TITLE'),
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
                const _FieldLabel('DATE'),
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
                      child: TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '60',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          suffixText: 'min',
                        ),
                        onChanged: (_) => _checkForConflicts(),
                        validator: (v) {
                          final val = int.tryParse(v ?? '');
                          if (val == null || val < 15) return 'Min 15';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // START TIME
                const _FieldLabel('START TIME'),
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
                const _FieldLabel('PERSON(S) TO MEET'),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'ronald@nugsoft.com',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.orange),
                              onPressed: () => _addAttendeeEmail(_emailController.text),
                            ),
                          ),
                          onChanged: _searchUsers,
                          onFieldSubmitted: _addAttendeeEmail,
                        ),
                        const SizedBox(height: 8),
                        if (_attendeeEmails.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            children: _attendeeEmails.map((email) {
                              return Chip(
                                label: Text(
                                  email,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                backgroundColor: AppColors.navy,
                                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                                onDeleted: () => _removeAttendeeEmail(email),
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
                                  _addAttendeeEmail(user['email']);
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
                const _FieldLabel('LOCATION'),
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
                            'Online (Zoom)',
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
                      hintText: 'Nugsoft boardroom, Kyanja',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    validator: (v) => _locationType == 'physical' && (v == null || v.trim().isEmpty)
                        ? 'Location is required'
                        : null,
                  ),
                if (_locationType == 'online')
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Paste or enter Zoom link',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    onChanged: (value) => setState(() => _zoomLink = value),
                    validator: (v) => _locationType == 'online' && (v == null || v.trim().isEmpty)
                        ? 'Zoom link is required'
                        : null,
                  ),
                const SizedBox(height: 20),

                // REMIND ME
                const _FieldLabel('REMIND ME'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(_reminders.length, (index) {
                    final reminder = _reminders[index];
                    final mins = reminder['minutes_before'] as int;
                    String label;
                    if (mins >= 60) {
                      label = '${mins ~/ 60} hr${mins ~/ 60 > 1 ? 's' : ''} before';
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
                if (_reminders.length < 3)
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey[700],
      ),
    );
  }
}
