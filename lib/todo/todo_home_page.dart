import 'package:flutter/material.dart';

import 'task.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<Task> _tasks = [];
  int _nextId = 1;

  void _openAddTaskModal() {
    final controller = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.media;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const ValueKey('input_task_description'),
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Descripción de la tarea'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<TaskPriority>(
                    key: const ValueKey('dropdown_priority'),
                    value: selectedPriority,
                    items: TaskPriority.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(_priorityLabel(p))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => selectedPriority = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    key: const ValueKey('btn_save_task'),
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      setState(() {
                        _tasks.add(Task(
                          id: 'task-${_nextId++}',
                          description: controller.text.trim(),
                          priority: selectedPriority,
                        ));
                      });
                      Navigator.of(modalContext).pop();
                    },
                    child: const Text('Guardar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteTask(String id) {
    setState(() => _tasks.removeWhere((task) => task.id == id));
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.baja:
        return 'Baja';
      case TaskPriority.media:
        return 'Media';
      case TaskPriority.alta:
        return 'Alta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tareas')),
      body: _tasks.isEmpty
          ? const Center(key: ValueKey('empty_state'), child: Text('No hay tareas pendientes'))
          : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Dismissible(
            key: ValueKey('task_item_${task.id}'),
            onDismissed: (_) => _deleteTask(task.id),
            background: Container(color: Colors.red),
            child: ListTile(
              title: Text(task.description),
              trailing: Chip(
                key: ValueKey('chip_priority_${task.id}'),
                label: Text(_priorityLabel(task.priority)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('fab_add_task'),
        onPressed: _openAddTaskModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}