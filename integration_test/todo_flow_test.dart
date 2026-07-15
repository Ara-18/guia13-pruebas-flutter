import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_testing_lab/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Flujo E2E - Gestión de Tareas (Todo App):', () {
    testWidgets('Debe crear una tarea con prioridad alta y luego eliminarla, volviendo al estado vacío',
            (WidgetTester tester) async {
          app.main();
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('empty_state')), findsOneWidget);

          await tester.tap(find.byKey(const ValueKey('fab_add_task')));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const ValueKey('input_task_description')),
            'Entregar reporte de QA a producción',
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('dropdown_priority')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Alta').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('btn_save_task')));
          await tester.pumpAndSettle();

          expect(find.text('Entregar reporte de QA a producción'), findsOneWidget);

          final priorityChip = find.byWidgetPredicate(
                (widget) => widget is Chip && widget.key.toString().contains('chip_priority_'),
          );
          expect(priorityChip, findsOneWidget);
          expect(find.text('Alta'), findsOneWidget);

          final taskItem = find.byWidgetPredicate(
                (widget) => widget is Dismissible && widget.key.toString().contains('task_item_'),
          );
          await tester.drag(taskItem, const Offset(-500, 0));
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('empty_state')), findsOneWidget);
          expect(find.text('Entregar reporte de QA a producción'), findsNothing);
        });
  });
}