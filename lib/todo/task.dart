enum TaskPriority { baja, media, alta }

class Task {
  final String id;
  final String description;
  final TaskPriority priority;

  Task({
    required this.id,
    required this.description,
    required this.priority,
  });
}