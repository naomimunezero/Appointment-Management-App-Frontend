import 'action_point.dart';

class Appointment {
  final int id;
  final String purpose;
  final String appointmentDate;
  final String startTime;
  final int durationMinutes;
  final String? personToMeet;
  final List<String> attendees;
  final String? discussionNotes;
  final String? location;
  final String status;
  final List<ActionPoint> actionPoints;

  Appointment({
    required this.id,
    required this.purpose,
    required this.appointmentDate,
    required this.startTime,
    required this.durationMinutes,
    this.personToMeet,
    required this.attendees,
    this.discussionNotes,
    this.location,
    required this.status,
    required this.actionPoints,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      purpose: json['purpose'] ?? '',
      appointmentDate: json['appointment_date'] ?? '',
      startTime: json['start_time'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      personToMeet: json['person_to_meet'],
      attendees: json['attendees'] != null
          ? List<String>.from(json['attendees'])
          : (json['person_to_meet'] != null ? [json['person_to_meet']] : []),
      discussionNotes: json['discussion_notes'],
      location: json['location'],
      status: json['status'] ?? 'upcoming',
      actionPoints: json['action_points'] != null
          ? (json['action_points'] as List).map((a) => ActionPoint.fromJson(a)).toList()
          : [],
    );
  }
}