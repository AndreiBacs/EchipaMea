import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/auth/session_controller.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../foreman/presentation/providers/projects_controller.dart';
import '../../application/worker_reports_api.dart';
import '../providers/worker_assigned_projects_provider.dart';
import '../../application/worker_foreman_inbox_controller.dart';
import 'worker_shell_page.dart';

class WorkerReportFlowPage extends ConsumerStatefulWidget {
  const WorkerReportFlowPage({super.key, required this.projectId});

  static String pathFor(String projectId) => '/worker/project/$projectId/report';

  final String projectId;

  @override
  ConsumerState<WorkerReportFlowPage> createState() =>
      _WorkerReportFlowPageState();
}

class _WorkerReportFlowPageState extends ConsumerState<WorkerReportFlowPage> {
  final _pageController = PageController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  final List<XFile> _photos = [];
  String? _memoPath;
  bool _recording = false;
  bool _memoUnsupported = false;
  bool _submitting = false;
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _descriptionController.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final project = ref.watch(projectsProvider.select((list) {
      for (final p in list) {
        if (p.id == widget.projectId) return p;
      }
      return null;
    }));
    final session = ref.watch(sessionProvider);
    final assigned = ref.watch(workerAssignedProjectsProvider);
    final ok = project != null &&
        session != null &&
        assigned.any((p) => p.id == project.id);

    if (!ok) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.workerReportTitle)),
        body: Center(child: Text(l10n.workerProjectNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workerReportTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: List.generate(3, (i) {
                final active = i == _pageIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                _PhotosStep(
                  l10n: l10n,
                  photos: _photos,
                  onAdd: _pickPhotos,
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                ),
                _MemoStep(
                  l10n: l10n,
                  recording: _recording,
                  memoPath: _memoPath,
                  memoUnsupported: _memoUnsupported,
                  onStart: _startRecording,
                  onStop: _stopRecording,
                  onClear: () => setState(() => _memoPath = null),
                ),
                _DescriptionStep(
                  l10n: l10n,
                  controller: _descriptionController,
                  isSubmitting: _submitting,
                  onSubmit: () => _submit(context, project, session),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_pageIndex > 0)
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Text(l10n.setupBack),
                  ),
                const Spacer(),
                if (_pageIndex < 2)
                  FilledButton(
                    onPressed: _submitting
                        ? null
                        : () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    },
                    child: Text(l10n.setupNext),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final l10n = context.l10n;
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      setState(() {
        for (final f in files) {
          if (_photos.length >= 8) break;
          _photos.add(f);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workerReportPhotoPickFailed)),
      );
    }
  }

  Future<void> _startRecording() async {
    final l10n = context.l10n;
    if (kIsWeb) {
      setState(() => _memoUnsupported = true);
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workerReportMicPermission)),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/worker_memo_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _memoUnsupported = false;
      });
    } catch (_) {
      setState(() => _memoUnsupported = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _recording = false;
      if (path != null && path.isNotEmpty) {
        _memoPath = path;
      }
    });
  }

  Future<void> _submit(
    BuildContext context,
    Project project,
    WorkerSession session,
  ) async {
    final l10n = context.l10n;
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workerReportNeedDescription)),
      );
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      await WorkerReportsApi().submitReport(
        projectId: project.id,
        projectName: project.name,
        employeeId: session.employeeId,
        employeeName: session.employeeName,
        description: description,
        submittedAt: DateTime.now(),
        photos: _photos,
        memoPath: _memoPath,
      );

      ref.read(workerForemanInboxProvider.notifier).submitReport(
            WorkerReportSubmittedEvent(
              at: DateTime.now().toUtc(),
              projectId: project.id,
              projectName: project.name,
              employeeId: session.employeeId,
              employeeName: session.employeeName,
              description: description,
              photoCount: _photos.length,
              hasVoiceMemo: _memoPath != null,
            ),
          );
      ref.read(projectsProvider.notifier).markProjectDone(project.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.workerReportSubmitted)),
      );
      context.go(WorkerShellPage.workPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.workerReportSubmitFailed}: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.l10n,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final List<XFile> photos;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workerReportPhotosStep,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.workerReportPhotosHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: photos.length >= 8 ? null : onAdd,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l10n.workerReportAddPhotos),
        ),
        const SizedBox(height: 16),
        ...List.generate(photos.length, (i) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(
                photos[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onRemove(i),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MemoStep extends StatelessWidget {
  const _MemoStep({
    required this.l10n,
    required this.recording,
    required this.memoPath,
    required this.memoUnsupported,
    required this.onStart,
    required this.onStop,
    required this.onClear,
  });

  final AppLocalizations l10n;
  final bool recording;
  final String? memoPath;
  final bool memoUnsupported;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workerReportMemoStep,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.workerReportMemoHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (memoUnsupported)
          Text(
            l10n.workerReportRecordingUnavailable,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (!recording)
              FilledButton.icon(
                onPressed: memoUnsupported ? null : onStart,
                icon: const Icon(Icons.mic),
                label: Text(l10n.workerReportStartRecording),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                label: Text(l10n.workerReportStopRecording),
              ),
          ],
        ),
        if (memoPath != null) ...[
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: Text(l10n.workerReportRecordingSaved),
            trailing: TextButton(onPressed: onClear, child: Text(l10n.cancel)),
          ),
        ],
      ],
    );
  }
}

class _DescriptionStep extends StatelessWidget {
  const _DescriptionStep({
    required this.l10n,
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final AppLocalizations l10n;
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.workerReportDescriptionStep,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            labelText: l10n.workerReportDescriptionHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(
            isSubmitting ? l10n.workerReportSubmitting : l10n.workerReportSubmit,
          ),
        ),
      ],
    );
  }
}
