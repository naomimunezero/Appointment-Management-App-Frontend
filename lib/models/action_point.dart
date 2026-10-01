class ActionPoint {
  final int id;
  final String description;
  final String? responsiblePerson;
  final DateTime? dueDate;
  final String status;
  final bool completed;
  final String? owner;

  ActionPoint({
    required this.id,
    required this.description,
    this.responsiblePerson,
    this.dueDate,
    required this.status,
    this.completed = false,
    this.owner,
  });

  factory ActionPoint.fromJson(Map<String, dynamic> json) {
    final rawCompleted = json['completed'];
    final completed = rawCompleted is bool
        ? rawCompleted
        : rawCompleted is num
            ? rawCompleted != 0
            : ['true', '1', 'completed', 'done'].contains(
                (rawCompleted ?? json['status'] ?? '').toString().toLowerCase(),
              );

    return ActionPoint(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.parse(json['id'].toString()),
      description: json['description'] ?? '',
      responsiblePerson: json['responsible_person'],
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      status: json['status'] ?? 'pending',
      completed: completed,
      owner: json['owner'],
    );
  }
}
