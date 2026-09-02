import 'package:flutter/material.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/new_task_due.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class AddTaskDialog extends StatefulWidget {
  final void Function(
    String title,
    DateTime? dueDate,
    int? projectId,
    int priority,
  )
  onAddTask;
  final String? title;
  final List<Project> projects;
  final int? initialProjectId;

  const AddTaskDialog({
    super.key,
    required this.onAddTask,
    this.title,
    this.projects = const [],
    this.initialProjectId,
  });

  @override
  State<StatefulWidget> createState() => AddTaskDialogState();
}

class AddTaskDialogState extends State<AddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.none;
  DateTime? dueDate;
  var textController = TextEditingController();
  int? selectedProjectId;
  int priority = 0;

  @override
  void initState() {
    super.initState();

    var title = widget.title;
    if (title != null) {
      textController.text = title;
    }
    selectedProjectId = widget.initialProjectId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      scrollable: true,
      contentPadding: const EdgeInsets.all(16.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            keyboardType: TextInputType.multiline,
            maxLines: null,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.newTaskName,
              hintText: l10n.newTaskExample,
              border: const OutlineInputBorder(),
            ),
            controller: textController,
          ),
          if (widget.projects.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: DropdownButtonFormField<int>(
                value: selectedProjectId,
                decoration: InputDecoration(
                  labelText: l10n.project,
                  border: const OutlineInputBorder(),
                ),
                items: widget.projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(
                          project.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProjectId = value;
                  });
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: DropdownButtonFormField<NewTaskDue>(
              value: newTaskDue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.dueDateLabel,
                prefixIcon: const Icon(Icons.event_outlined),
                border: const OutlineInputBorder(),
              ),
              selectedItemBuilder: (context) => _dueOptions
                  .map(
                    (option) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        option == NewTaskDue.custom && dueDate != null
                            ? dueDate!.formatShort()
                            : _dueLabel(l10n, option),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              items: _dueOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(_dueLabel(l10n, option)),
                    ),
                  )
                  .toList(),
              onChanged: _changeDueDate,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: DropdownButtonFormField<int>(
              value: priority,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.priority,
                border: const OutlineInputBorder(),
              ),
              items: List.generate(
                6,
                (value) => DropdownMenuItem(
                  value: value,
                  child: Row(
                    children: [
                      Icon(
                        value == 0 ? Icons.flag_outlined : Icons.flag,
                        key: ValueKey('priority-icon-$value'),
                        color: _priorityColor(context, value),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(priorityToString(l10n, value))),
                    ],
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  priority = value ?? 0;
                });
              },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(l10n.add),
          onPressed: () {
            if (textController.text.isNotEmpty) {
              widget.onAddTask(
                textController.text,
                dueDate,
                selectedProjectId,
                priority,
              );
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  static const _dueOptions = [
    NewTaskDue.none,
    NewTaskDue.today,
    NewTaskDue.tomorrow,
    NewTaskDue.nextMonday,
    NewTaskDue.weekend,
    NewTaskDue.laterThisWeek,
    NewTaskDue.nextWeek,
    NewTaskDue.custom,
  ];

  String _dueLabel(AppLocalizations l10n, NewTaskDue option) {
    return switch (option) {
      NewTaskDue.none => l10n.dueOptionNone,
      NewTaskDue.today => l10n.dueOptionToday,
      NewTaskDue.tomorrow => l10n.dueOptionTomorrow,
      NewTaskDue.nextMonday => l10n.dueOptionNextMonday,
      NewTaskDue.weekend => l10n.dueOptionThisWeekend,
      NewTaskDue.laterThisWeek => l10n.dueOptionLaterThisWeek,
      NewTaskDue.nextWeek => l10n.dueInOneWeek,
      NewTaskDue.custom => l10n.dueOptionCustom,
    };
  }

  Color _priorityColor(BuildContext context, int value) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>();
    final warning = appColors?.warning ?? Colors.orange;
    final danger = appColors?.danger ?? Colors.red;

    return switch (value) {
      1 => appColors?.success ?? Colors.green,
      2 => warning,
      3 => danger,
      4 => danger,
      5 => danger,
      _ => theme.colorScheme.onSurfaceVariant,
    };
  }

  Future<void> _changeDueDate(NewTaskDue? option) async {
    if (option == null) {
      return;
    }

    if (option == NewTaskDue.custom) {
      final picked = await _pickCustomDueDate();
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        newTaskDue = option;
        dueDate = picked;
      });
      return;
    }

    setState(() {
      newTaskDue = option;
      dueDate = option == NewTaskDue.none
          ? null
          : option.calculateDate(DateTime.now());
    });
  }

  Future<DateTime?> _pickCustomDueDate() async {
    final initial = dueDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
