import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
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
import '../../application/worker_reports_api_provider.dart';
import '../providers/worker_assigned_projects_provider.dart';
import '../../application/worker_foreman_inbox_controller.dart';
import 'worker_shell_page.dart';

class WorkerReportFlowPage extends ConsumerStatefulWidget {
  const WorkerReportFlowPage({
    super.key,
    required this.projectId,
    required this.phaseId,
  });

  static String pathFor({
    required String projectId,
    required String phaseId,
  }) => '/worker/project/$projectId/phase/$phaseId/report';

  final String projectId;
  final String phaseId;

  @override
  ConsumerState<WorkerReportFlowPage> createState() =>
      _WorkerReportFlowPageState();
}

class _WorkerReportFlowPageState extends ConsumerState<WorkerReportFlowPage> {
  final _pageController = PageController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _memoPlayer = AudioPlayer();

  final List<XFile> _photos = [];
  String? _memoPath;
  bool _recording = false;
  bool _playingMemo = false;
  bool _memoUnsupported = false;
  bool _submitting = false;
  int _pageIndex = 0;
  StreamSubscription<void>? _memoCompleteSub;
  final Stopwatch _recordingStopwatch = Stopwatch();
  Timer? _recordingTicker;
  String _recordingElapsedLabel = '00:00';

  @override
  void initState() {
    super.initState();
    _memoCompleteSub = _memoPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playingMemo = false);
    });
  }

  @override
  void dispose() {
    unawaited(_memoPlayer.stop());
    unawaited(_memoPlayer.dispose());
    unawaited(_memoCompleteSub?.cancel());
    unawaited(_deleteMemoFile(_memoPath));
    _pageController.dispose();
    _descriptionController.dispose();
    unawaited(_audioRecorder.dispose());
    _recordingTicker?.cancel();
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
    final phase = project?.phases.where((p) => p.id == widget.phaseId).firstOrNull;
    final workerAssignedToPhase = session != null &&
        phase != null &&
        phase.assignedEmployeeIds.contains(session.employeeId);
    final ok = project != null &&
        session != null &&
        assigned.any((p) => p.id == project.id) &&
        workerAssignedToPhase;

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
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: [
                _PhotosStep(
                  l10n: l10n,
                  photos: _photos,
                  onAddFromGallery: _pickPhotosFromGallery,
                  onCapturePhoto: _capturePhoto,
                  onPreview: _openPhotoPreview,
                  onRemove: (i) => setState(() => _photos.removeAt(i)),
                ),
                _MemoStep(
                  l10n: l10n,
                  recording: _recording,
                  recordingElapsedLabel: _recordingElapsedLabel,
                  memoPath: _memoPath,
                  memoUnsupported: _memoUnsupported,
                  isPlaying: _playingMemo,
                  onStart: _startRecording,
                  onStop: _stopRecording,
                  onTogglePlay: _toggleMemoPlayback,
                  onClear: _clearMemo,
                ),
                _DescriptionStep(
                  l10n: l10n,
                  controller: _descriptionController,
                  isSubmitting: _submitting,
                  onSubmit: () => _submit(context, project, phase, session),
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

  Future<void> _pickPhotosFromGallery() async {
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

  Future<void> _capturePhoto() async {
    final l10n = context.l10n;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() {
        if (_photos.length < 8) {
          _photos.add(file);
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
      _recordingStopwatch
        ..reset()
        ..start();
      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordingElapsedLabel = _formatElapsed(_recordingStopwatch.elapsed);
        });
      });
      setState(() {
        _recording = true;
        _memoUnsupported = false;
        _recordingElapsedLabel = '00:00';
      });
    } catch (_) {
      setState(() => _memoUnsupported = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    _recordingTicker?.cancel();
    _recordingStopwatch.stop();
    setState(() {
      _recording = false;
      _playingMemo = false;
      if (path != null && path.isNotEmpty) {
        _memoPath = path;
      }
    });
  }

  Future<void> _clearMemo() async {
    await _memoPlayer.stop();
    final toDelete = _memoPath;
    setState(() {
      _memoPath = null;
      _playingMemo = false;
    });
    await _deleteMemoFile(toDelete);
  }

  Future<void> _toggleMemoPlayback() async {
    final path = _memoPath;
    if (path == null || path.trim().isEmpty) return;
    if (kIsWeb) {
      if (mounted) {
        setState(() => _memoUnsupported = true);
      }
      return;
    }
    if (_playingMemo) {
      await _memoPlayer.stop();
      if (mounted) {
        setState(() => _playingMemo = false);
      }
      return;
    }
    try {
      await _memoPlayer.stop();
      await _memoPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() {
          _playingMemo = true;
          _memoUnsupported = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _memoUnsupported = true);
      }
    }
  }

  Future<void> _openPhotoPreview(XFile photo) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: context.l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: _LargePhotoPreview(file: photo),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    Project project,
    ProjectPhase phase,
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
      await ref.read(workerReportsApiProvider).submitReport(
        projectId: project.id,
        projectName: project.name,
        phaseId: phase.id,
        phaseName: phase.name,
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
              phaseId: phase.id,
              phaseName: phase.name,
              employeeId: session.employeeId,
              employeeName: session.employeeName,
              description: description,
              photoCount: _photos.length,
              hasVoiceMemo: _memoPath != null,
            ),
          );
      await _memoPlayer.stop();
      await _deleteMemoFile(_memoPath);
      if (mounted) {
        setState(() {
          _memoPath = null;
          _playingMemo = false;
        });
      }

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

  Future<void> _deleteMemoFile(String? path) async {
    if (kIsWeb) return;
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup for temporary recordings.
    }
  }

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    if (kIsWeb) {
      return SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                snapshot.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(file.path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined, size: 32),
      ),
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({
    required this.l10n,
    required this.photos,
    required this.onAddFromGallery,
    required this.onCapturePhoto,
    required this.onPreview,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final List<XFile> photos;
  final VoidCallback onAddFromGallery;
  final VoidCallback onCapturePhoto;
  final Future<void> Function(XFile photo) onPreview;
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: photos.length >= 8 ? null : onAddFromGallery,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l10n.workerReportAddPhotos),
            ),
            OutlinedButton.icon(
              onPressed: photos.length >= 8 ? null : onCapturePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.workerReportCapturePhoto),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(photos.length, (i) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: GestureDetector(
                onTap: () => onPreview(photos[i]),
                child: _PhotoThumbnail(file: photos[i]),
              ),
              title: Text(
                photos[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.workerReportViewPhoto),
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
    required this.recordingElapsedLabel,
    required this.memoPath,
    required this.memoUnsupported,
    required this.isPlaying,
    required this.onStart,
    required this.onStop,
    required this.onTogglePlay,
    required this.onClear,
  });

  final AppLocalizations l10n;
  final bool recording;
  final String recordingElapsedLabel;
  final String? memoPath;
  final bool memoUnsupported;
  final bool isPlaying;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onTogglePlay;
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
        if (recording) ...[
          const SizedBox(height: 12),
          _RecordingIndicator(
            inProgressLabel: l10n.inProgress,
            elapsedLabel: recordingElapsedLabel,
          ),
        ],
        if (memoPath != null) ...[
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: Text(l10n.workerReportRecordingSaved),
            subtitle: Row(
              children: [
                TextButton.icon(
                  onPressed: onTogglePlay,
                  icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    isPlaying
                        ? l10n.workerReportStopPlayback
                        : l10n.workerReportPlayMemo,
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: Text(l10n.workerReportRemoveMemo),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator({
    required this.inProgressLabel,
    required this.elapsedLabel,
  });

  final String inProgressLabel;
  final String elapsedLabel;

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.7,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseController,
            child: Icon(Icons.mic, color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.inProgressLabel}: ${widget.elapsedLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargePhotoPreview extends StatelessWidget {
  const _LargePhotoPreview({required this.file});

  final XFile file;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<Uint8List>(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Image.memory(snapshot.data!, fit: BoxFit.contain);
        },
      );
    }
    return Image.file(
      File(file.path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image_outlined, size: 40),
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
