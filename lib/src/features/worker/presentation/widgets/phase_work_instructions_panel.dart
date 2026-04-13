import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:universal_io/io.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../foreman/domain/entities/project.dart';

/// Read-only work instructions: each step with its own photos and voice notes.
class PhaseWorkInstructionsPanel extends StatelessWidget {
  const PhaseWorkInstructionsPanel({
    super.key,
    required this.l10n,
    required this.phase,
  });

  final AppLocalizations l10n;
  final ProjectPhase phase;

  bool _hasContent(PhaseWorkInstruction i) {
    return i.text.trim().isNotEmpty ||
        i.photoPaths.isNotEmpty ||
        i.audioPaths.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final items = phase.workInstructions.where(_hasContent).toList();
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workerPhaseWorkInstructionsTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (stepIndex) {
            final ins = items[stepIndex];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ins.text.trim().isNotEmpty) ...[
                        Text(
                          '${stepIndex + 1}. ${ins.text.trim()}',
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (ins.photoPaths.isNotEmpty ||
                            ins.audioPaths.isNotEmpty)
                          const SizedBox(height: 10),
                      ],
                      if (ins.photoPaths.isNotEmpty) ...[
                        Text(
                          l10n.phaseInstructionPhotosForStep,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ins.photoPaths
                              .map((p) => _WorkerInstructionPhotoThumb(path: p))
                              .toList(),
                        ),
                        if (ins.audioPaths.isNotEmpty)
                          const SizedBox(height: 10),
                      ],
                      if (ins.audioPaths.isNotEmpty) ...[
                        Text(
                          l10n.phaseInstructionAudioForStep,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        ...List.generate(ins.audioPaths.length, (ai) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _InstructionAudioPlayRow(
                              l10n: l10n,
                              path: ins.audioPaths[ai],
                              index: ai,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _WorkerInstructionPhotoThumb extends StatelessWidget {
  const _WorkerInstructionPhotoThumb({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    const size = 80.0;
    if (kIsWeb) {
      return SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List>(
          future: XFile(path).readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Icon(Icons.broken_image_outlined, size: 32),
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

class _InstructionAudioPlayRow extends StatefulWidget {
  const _InstructionAudioPlayRow({
    required this.l10n,
    required this.path,
    required this.index,
  });

  final AppLocalizations l10n;
  final String path;
  final int index;

  @override
  State<_InstructionAudioPlayRow> createState() =>
      _InstructionAudioPlayRowState();
}

class _InstructionAudioPlayRowState extends State<_InstructionAudioPlayRow> {
  final _player = AudioPlayer();
  var _playing = false;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    unawaited(_completeSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (kIsWeb) return;
    try {
      if (_playing) {
        await _player.stop();
        setState(() => _playing = false);
        return;
      }
      await _player.stop();
      await _player.play(DeviceFileSource(widget.path));
      setState(() => _playing = true);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: const Icon(Icons.volume_off_outlined),
        title: Text(
          '${widget.l10n.phaseInstructionVoiceNoteLabel} ${widget.index + 1}',
        ),
        subtitle: Text(
          widget.l10n.workerPhaseInstructionAudioWebHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_playing ? Icons.stop_circle_outlined : Icons.play_circle),
      title: Text(
        '${widget.l10n.phaseInstructionVoiceNoteLabel} ${widget.index + 1}',
      ),
      trailing: TextButton(
        onPressed: _toggle,
        child: Text(
          _playing
              ? widget.l10n.phaseInstructionStop
              : widget.l10n.phaseInstructionPlay,
        ),
      ),
    );
  }
}
