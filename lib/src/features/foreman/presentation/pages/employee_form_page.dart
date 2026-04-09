import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/adaptive_breakpoints.dart';
import 'foreman_shell_page.dart';
import '../providers/team_controller.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, this.employeeId});

  static const createPath = '/foreman/team/new';
  static const editPath = '/foreman/team/:id/edit';

  final String? employeeId;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late int _workStartHour;
  late int _workEndHour;
  late Set<int> _workingDays;

  @override
  void initState() {
    super.initState();
    final existing = widget.employeeId == null
        ? null
        : ref.read(teamProvider.notifier).findById(widget.employeeId!);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _roleController = TextEditingController(text: existing?.role ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _workStartHour = existing?.workStartHour ?? 8;
    _workEndHour = existing?.workEndHour ?? 18;
    _workingDays = {...(existing?.workingDays ?? {1, 2, 3, 4, 5})};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employeeId != null;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? l10n.employeeFormEditTitle : l10n.employeeFormAddTitle,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sizeClass = AdaptiveBreakpoints.sizeClassForWidth(
            constraints.maxWidth,
          );
          final formWidth = switch (sizeClass) {
            AdaptiveSizeClass.compact => constraints.maxWidth,
            AdaptiveSizeClass.medium => 640.0,
            AdaptiveSizeClass.expanded => 720.0,
          };
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: formWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.employeeNameLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _roleController,
                      decoration: InputDecoration(labelText: l10n.roleLabel),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.profileEmailLabel,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: l10n.profilePhoneLabel,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.workingDaysLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(_weekdayLabel(l10n, day)),
                            selected: _workingDays.contains(day),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _workingDays.add(day);
                                } else {
                                  _workingDays.remove(day);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _workStartHour,
                            decoration: InputDecoration(
                              labelText: l10n.workStartHourLabel,
                            ),
                            items: [
                              for (var hour = 0; hour < 24; hour++)
                                DropdownMenuItem(
                                  value: hour,
                                  child: Text(_hourLabel(hour)),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _workStartHour = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _workEndHour,
                            decoration: InputDecoration(
                              labelText: l10n.workEndHourLabel,
                            ),
                            items: [
                              for (var hour = 0; hour < 24; hour++)
                                DropdownMenuItem(
                                  value: hour,
                                  child: Text(_hourLabel(hour)),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _workEndHour = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                context.go(ForemanShellPage.teamPath),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _save(context, isEdit: isEdit),
                            child: Text(
                              isEdit ? l10n.saveChanges : l10n.createEmployee,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _save(BuildContext context, {required bool isEdit}) {
    final name = _nameController.text.trim();
    final role = _roleController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty ||
        role.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        _workingDays.isEmpty ||
        _workStartHour == _workEndHour) {
      return;
    }

    if (isEdit) {
      ref
          .read(teamProvider.notifier)
          .updateEmployee(
            id: widget.employeeId!,
            name: name,
            role: role,
            email: email,
            phone: phone,
            workStartHour: _workStartHour,
            workEndHour: _workEndHour,
            workingDays: _workingDays,
          );
    } else {
      ref
          .read(teamProvider.notifier)
          .addEmployee(
            name: name,
            role: role,
            email: email,
            phone: phone,
            workStartHour: _workStartHour,
            workEndHour: _workEndHour,
            workingDays: _workingDays,
          );
    }

    Navigator.of(context).pop();
  }

  String _weekdayLabel(AppLocalizations l10n, int day) {
    return switch (day) {
      1 => l10n.weekdayMon,
      2 => l10n.weekdayTue,
      3 => l10n.weekdayWed,
      4 => l10n.weekdayThu,
      5 => l10n.weekdayFri,
      6 => l10n.weekdaySat,
      _ => l10n.weekdaySun,
    };
  }

  String _hourLabel(int hour) {
    final hh = hour.toString().padLeft(2, '0');
    return '$hh:00';
  }
}
