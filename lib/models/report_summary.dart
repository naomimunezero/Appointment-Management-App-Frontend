import 'appointment.dart';

class ReportSummary {
  final int appointmentsTotal;
  final int held;
  final int missed;
  final int cancelled;
  final int peopleMet;
  final int actionPointsTotal;
  final int actionPointsDone;
  final List<Appointment> appointments;

  ReportSummary({
    required this.appointmentsTotal,
    required this.held,
    required this.missed,
    required this.cancelled,
    required this.peopleMet,
    required this.actionPointsTotal,
    required this.actionPointsDone,
    required this.appointments,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    return ReportSummary(
      appointmentsTotal: json['appointments_total'] ?? 0,
      held: json['held'] ?? 0,
      missed: json['missed'] ?? 0,
      cancelled: json['cancelled'] ?? 0,
      peopleMet: json['people_met'] ?? 0,
      actionPointsTotal: json['action_points_total'] ?? 0,
      actionPointsDone: json['action_points_done'] ?? 0,
      appointments: (json['appointments'] as List? ?? [])
          .map((a) => Appointment.fromJson(a))
          .toList(),
    );
  }
}