import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _logout(BuildContext context) async {
    await ApiService.clearToken();
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are logged out. Please login again to continue.'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.navy,
      ),
    );
    
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    const bool hasAssistant = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  children: [
                    _defaultRemindersCard(),
                    const SizedBox(height: 18),
                    _toggleSection(hasAssistant),
                    const SizedBox(height: 18),
                    _profileRow(context),
                    const SizedBox(height: 18),
                    _accessSection(context),
                  ],
                ),
              ),
            ),
          ],
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

  Widget _defaultRemindersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEFAULT REMINDERS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _reminderPill('5 hrs before', true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _reminderPill('30 min before', false),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 42,
                height: 42,
                child: Center(
                  child: Icon(Icons.add, color: AppColors.orange, size: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Applied to every new appointment; can be changed per appointment.',
            style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _reminderPill(String title, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.orange.withOpacity(0.12) : Colors.white,
        border: Border.all(color: active ? AppColors.orange : Colors.grey.shade300, width: 1.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.orange : Colors.black87,
        ),
      ),
    );
  }

  Widget _toggleSection(bool hasAssistant) {
    final rows = <Widget>[
      _toggleRow('Daily morning summary', 'Your day at a glance, 6:30 AM', true),
      const Divider(height: 20),
      _toggleRow('Overdue action alerts', 'Notify when a follow-up passes its due date', true),
    ];

    if (hasAssistant) {
      rows.add(const Divider(height: 20));
      rows.add(_toggleRow('Assistant activity alerts', 'When Joan adds or changes an appointment', true));
    }

    rows.add(const Divider(height: 20));
    rows.add(_toggleRow('Missed-appointment nudge', 'Prompt to record or reschedule after end time', false));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(children: rows),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool enabled) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: enabled,
          activeColor: AppColors.green,
          onChanged: (_) {},
        ),
      ],
    );
  }

  Widget _profileRow(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile & password',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Vincent Matsiko • vincent@nugsoft.com',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 28, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _accessSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, left: 6, right: 6, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(
              'Users & access',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy),
            ),
          ),
         /* Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your account', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Managing: Vincent’s account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      ],
                    ),
                  ),
                  Icon(Icons.swap_horiz, color: AppColors.navy),
                ],
              ),
            ),
          ),*/
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pushNamed(context, '/invite-assistant'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Invite Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.orange),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/invite-assistant'),
      child: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          color: AppColors.orange,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _miniAccessItem(IconData icon, String label, bool selected) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.navy : Colors.grey[600], size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.navy : Colors.grey[600],
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
