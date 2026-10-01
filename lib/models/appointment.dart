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
  final String? locationType;
  final String? onlineLink;
  final String status;
  final List<ActionPoint> actionPoints;
  final List<Map<String, String>> attendeeDetails;
  final List<Map<String, dynamic>> reminders;
  final String? heldAt;

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
    this.locationType,
    this.onlineLink,
    required this.status,
    required this.actionPoints,
    required this.attendeeDetails,
    required this.reminders,
    this.heldAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final rawAttendees = json['attendees'];
    final attendeeDetails = rawAttendees is List
        ? rawAttendees.map((attendee) {
            if (attendee is Map) {
              final name = (attendee['name'] ?? attendee['email'] ?? '').toString();
              return <String, String>{
                'name': name,
                'email': (attendee['email'] ?? '').toString(),
              };
            }
            final value = attendee.toString();
            return <String, String>{'name': value, 'email': ''};
          }).toList()
        : (json['person_to_meet'] != null
            ? <Map<String, String>>[
                {'name': json['person_to_meet'].toString(), 'email': ''},
              ]
            : <Map<String, String>>[]);

    return Appointment(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.parse(json['id'].toString()),
      purpose: json['purpose'] ?? '',
      appointmentDate: json['appointment_date'] ?? '',
      startTime: json['start_time'] ?? '',
      durationMinutes: json['duration_minutes'] is num
          ? (json['duration_minutes'] as num).toInt()
          : int.tryParse(json['duration_minutes']?.toString() ?? '') ?? 0,
      personToMeet: json['person_to_meet'],

      attendees: attendeeDetails.map((attendee) => attendee['name'] ?? '').toList(),

      discussionNotes: json['discussion_notes'],
      location: json['location'],
      locationType: json['location_type'],
      // The update API persists online meeting URLs in `location`.
      onlineLink: json['online_link'] ??
          (json['location_type'] == 'online' ? json['location'] : null),
      status: json['status'] ?? 'upcoming',
      actionPoints: json['action_points'] != null
          ? (json['action_points'] as List).map((a) => ActionPoint.fromJson(a)).toList()
          : [],
      attendeeDetails: attendeeDetails,
      reminders: json['reminders'] is List
          ? List<Map<String, dynamic>>.from(
              (json['reminders'] as List).whereType<Map>().map(Map<String, dynamic>.from),
            )
          : [],
      heldAt: json['held_at'],
    );
  }
}
