class ActionPoint {
  final int id;
  final String description;
  final String? responsiblePerson;
  final String? dueDate;
  final String status;

  ActionPoint({
    required this.id,
    required this.description,
    this.responsiblePerson,
    this.dueDate,
    required this.status,
  });

  factory ActionPoint.fromJson(Map<String, dynamic> json) {
    return ActionPoint(
      id: json['id'],
      description: json['description'] ?? '',
      responsiblePerson: json['responsible_person'],
      dueDate: json['due_date'],
      status: json['status'] ?? 'pending',
    );
  }
}