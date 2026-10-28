import '../i18n/app_localizations.dart';
import 'api_exception.dart';

/// A message for [error] the user can act on, in their language.
///
/// The server's own `error.message` is English text meant for logs, so the
/// mapping goes by `error.code` and status instead. Anything unrecognised
/// falls back to the generic message rather than leaking `Exception: ...`
/// strings into the UI.
String apiErrorMessage(AppLocalizations l10n, Object? error) {
  if (error is! ApiException) return l10n.genericErrorMessage;
  if (error.isNetwork) return l10n.apiErrorNetwork;

  switch (error.code) {
    case 'INVALID_CREDENTIALS':
      return l10n.apiErrorInvalidCredentials;
    case 'ACCOUNT_DISABLED':
      return l10n.apiErrorAccountDisabled;
    case 'RATE_LIMITED':
      return l10n.apiErrorRateLimited;
    case 'VALIDATION_FAILED':
      return l10n.apiErrorValidation;
  }

  return switch (error.status) {
    401 => l10n.apiErrorSessionExpired,
    403 => l10n.apiErrorForbidden,
    404 || 410 => l10n.apiErrorNotFound,
    400 || 422 => l10n.apiErrorValidation,
    429 => l10n.apiErrorRateLimited,
    >= 500 => l10n.apiErrorServer,
    _ => l10n.genericErrorMessage,
  };
}
