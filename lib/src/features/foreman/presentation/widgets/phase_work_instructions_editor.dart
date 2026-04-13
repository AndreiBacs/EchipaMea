import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, listEquals;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../domain/entities/project.dart';

/// Latest values from [PhaseWorkInstructionsEditor].
class PhaseWorkInstructionsSnapshot {
  const PhaseWorkInstructionsSnapshot({required this.items});

  final List<PhaseWorkInstruction> items;

  static const empty = PhaseWorkInstructionsSnapshot(items: []);

  /// Non-empty text rows only, trimmed (stable ids and media lists kept).
  List<PhaseWorkInstruction> forPersistence() {
    return [
      for (final i in items)
        if (i.text.trim().isNotEmpty)
          PhaseWorkInstruction(
            id: i.id,
            text: i.text.trim(),
            photoPaths: List<String>.from(i.photoPaths),
            audioPaths: List<String>.from(i.audioPaths),
          ),
    ];
  }
}

class _InstructionEditRow {
  _InstructionEditRow({
    required this.id,
    required String text,
    List<String>? photoPaths,
    List<String>? audioPaths,
  })  : textController = TextEditingController(text: text),
        photoPaths = List<String>.from(photoPaths ?? []),
        audioPaths = List<String>.from(audioPaths ?? []);

  final String id;
  final TextEditingController textController;
  final List<String> photoPaths;
  final List<String> audioPaths;

  void dispose() {
    textController.dispose();
  }
}

/// Foreman UI: each instruction has its own photos and voice memos.
class PhaseWorkInstructionsEditor extends StatefulWidget {
  const PhaseWorkInstructionsEditor({
    super.key,
    required this.l10n,
    required this.readOnly,
    this.initialItems = const [],
    this.onChanged,
  });

  final AppLocalizations l10n;
  final bool readOnly;
  final List<PhaseWorkInstruction> initialItems;
  final ValueChanged<PhaseWorkInstructionsSnapshot>? onChanged;

  @override
  State<PhaseWorkInstructionsEditor> createState() =>
      PhaseWorkInstructionsEditorState();
}

class PhaseWorkInstructionsEditorState extends State<PhaseWorkInstructionsEditor> {
  static const _maxPhotosPerRow = 8;
  static const _maxAudioPerRow = 5;

  late List<_InstructionEditRow> _rows;

  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  var _recording = false;
  int? _recordingRowIndex;
  var _audioUnsupported = false;

  Timer? _debounce;

  static String _newId() => 'wi_${DateTime.now().microsecondsSinceEpoch}';

  static bool _sameInitialItems(
    List<PhaseWorkInstruction> a,
    List<PhaseWorkInstruction> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].text != b[i].text) return false;
      if (!listEquals(a[i].photoPaths, b[i].photoPaths)) return false;
      if (!listEquals(a[i].audioPaths, b[i].audioPaths)) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _rows = _rowsFromInitial(widget.initialItems);
    for (final r in _rows) {
      r.textController.addListener(_notifyDebounced);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  List<_InstructionEditRow> _rowsFromInitial(List<PhaseWorkInstruction> items) {
    if (items.isEmpty) {
      return [_InstructionEditRow(id: _newId(), text: '')];
    }
    return [
      for (final i in items)
        _InstructionEditRow(
          id: i.id,
          text: i.text,
          photoPaths: i.photoPaths,
          audioPaths: i.audioPaths,
        ),
    ];
  }

  @override
  void didUpdateWidget(covariant PhaseWorkInstructionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameInitialItems(oldWidget.initialItems, widget.initialItems)) {
      return;
    }
    for (final r in _rows) {
      r.textController.removeListener(_notifyDebounced);
      r.dispose();
    }
    _rows = _rowsFromInitial(widget.initialItems);
    for (final r in _rows) {
      r.textController.addListener(_notifyDebounced);
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final r in _rows) {
      r.textController.removeListener(_notifyDebounced);
      r.dispose();
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _notifyDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _notify);
  }

  void _notify() {
    widget.onChanged?.call(buildSnapshot());
  }

  PhaseWorkInstructionsSnapshot buildSnapshot() {
    return PhaseWorkInstructionsSnapshot(
      items: [
        for (final r in _rows)
          PhaseWorkInstruction(
            id: r.id,
            text: r.textController.text,
            photoPaths: List<String>.from(r.photoPaths),
            audioPaths: List<String>.from(r.audioPaths),
          ),
      ],
    );
  }

  Future<void> _pickPhotosForRow(int rowIndex) async {
    final row = _rows[rowIndex];
    try {
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      setState(() {
        for (final f in files) {
          if (row.photoPaths.length >= _maxPhotosPerRow) break;
          row.photoPaths.add(f.path);
        }
      });
      _notify();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l10n.workerReportPhotoPickFailed)),
      );
    }
  }

  Future<void> _startRecording(int rowIndex) async {
    final l10n = widget.l10n;
    final row = _rows[rowIndex];
    if (kIsWeb) {
      setState(() => _audioUnsupported = true);
      return;
    }
    if (row.audioPaths.length >= _maxAudioPerRow) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.workerReportMicPermission)),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/phase_instruction_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordingRowIndex = rowIndex;
        _audioUnsupported = false;
      });
    } catch (_) {
      setState(() => _audioUnsupported = true);
    }
  }

  Future<void> _stopRecording() async {
    final rowIndex = _recordingRowIndex;
    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _recordingRowIndex = null;
      if (rowIndex != null &&
          path != null &&
          path.isNotEmpty &&
          rowIndex < _rows.length &&
          _rows[rowIndex].audioPaths.length < _maxAudioPerRow) {
        _rows[rowIndex].audioPaths.add(path);
      }
    });
    _notify();
  }

  void _removePhoto(int rowIndex, int photoIndex) {
    setState(() => _rows[rowIndex].photoPaths.removeAt(photoIndex));
    _notify();
  }

  void _removeAudio(int rowIndex, int audioIndex) {
    setState(() => _rows[rowIndex].audioPaths.removeAt(audioIndex));
    _notify();
  }

  void _addRow() {
    final r = _InstructionEditRow(id: _newId(), text: '');
    r.textController.addListener(_notifyDebounced);
    setState(() => _rows.add(r));
    _notify();
  }

  void _removeRow(int i) {
    if (_rows.length <= 1) {
      _rows[i].textController.clear();
      setState(() {
        _rows[i].photoPaths.clear();
        _rows[i].audioPaths.clear();
      });
      _notify();
      return;
    }
    final removed = _rows.removeAt(i);
    removed.textController.removeListener(_notifyDebounced);
    removed.dispose();
    if (_recordingRowIndex != null) {
      if (_recordingRowIndex == i) {
        unawaited(_recorder.stop());
        _recording = false;
        _recordingRowIndex = null;
      } else if (_recordingRowIndex! > i) {
        _recordingRowIndex = _recordingRowIndex! - 1;
      }
    }
    setState(() {});
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.phaseWorkInstructionsTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.phaseWorkInstructionsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_rows.length, (i) {
          final row = _rows[i];
          final recordingHere =
              _recording && _recordingRowIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.textController,
                            readOnly: widget.readOnly,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              labelText:
                                  '${l10n.phaseInstructionStepLabel} ${i + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (!widget.readOnly) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: l10n.phaseRemoveInstructionStep,
                            onPressed: () => _removeRow(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.phaseInstructionPhotosForStep,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    if (!widget.readOnly)
                      OutlinedButton.icon(
                        onPressed: row.photoPaths.length >= _maxPhotosPerRow
                            ? null
                            : () => _pickPhotosForRow(i),
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(l10n.phaseInstructionAddPhotos),
                      ),
                    if (row.photoPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(row.photoPaths.length, (pi) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _InstructionPhotoThumb(path: row.photoPaths[pi]),
                              if (!widget.readOnly)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Material(
                                    color: theme.colorScheme.errorContainer,
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      tooltip: l10n.phaseInstructionRemovePhoto,
                                      icon: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: theme.colorScheme.onErrorContainer,
                                      ),
                                      onPressed: () => _removePhoto(i, pi),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      l10n.phaseInstructionAudioForStep,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    if (_audioUnsupported)
                      Text(
                        l10n.workerReportRecordingUnavailable,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    if (!widget.readOnly && !_audioUnsupported) ...[
                      if (recordingHere)
                        FilledButton.tonalIcon(
                          onPressed: _stopRecording,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(l10n.workerReportStopRecording),
                        )
                      else
                        FilledButton.tonalIcon(
                          onPressed: row.audioPaths.length >= _maxAudioPerRow
                              ? null
                              : () => _startRecording(i),
                          icon: const Icon(Icons.mic_none),
                          label: Text(l10n.phaseInstructionAddVoiceNote),
                        ),
                    ],
                    if (row.audioPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...List.generate(row.audioPaths.length, (ai) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.graphic_eq, size: 20),
                          title: Text(
                            '${l10n.phaseInstructionVoiceNoteLabel} ${ai + 1}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: !widget.readOnly
                              ? IconButton(
                                  tooltip: l10n.phaseInstructionRemoveAudio,
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeAudio(i, ai),
                                )
                              : null,
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        if (!widget.readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: Text(l10n.phaseAddInstructionStep),
            ),
          ),
      ],
    );
  }
}

class _InstructionPhotoThumb extends StatelessWidget {
  const _InstructionPhotoThumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    if (kIsWeb) {
      return SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List>(
          future: XFile(path).readAsBytes(),
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
        File(path),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined, size: 32),
      ),
    );
  }
}
