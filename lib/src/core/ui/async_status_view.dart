import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../network/api_error_messages.dart';

extension AsyncValueCurrent<T> on AsyncValue<T> {
  /// The data a screen may show, or null while it should show
  /// [AsyncStatusView] instead.
  ///
  /// Unlike [AsyncValue.value], this drops the previous data after a failed
  /// load and while reloading for a changed dependency. Foreman data reloads
  /// when a different foreman signs in, and the old data belongs to the
  /// previous company.
  T? get current => hasError || isReloading ? null : value;
}

/// What to show while an [AsyncValue] has no [AsyncValueCurrent.current]
/// data: a spinner while it loads, or the error with a retry button.
class AsyncStatusView extends StatelessWidget {
  const AsyncStatusView(this.value, {super.key, required this.onRetry});

  final AsyncValue<Object?> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading || !value.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              apiErrorMessage(l10n, value.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
