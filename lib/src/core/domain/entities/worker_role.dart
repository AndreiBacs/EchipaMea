import '../../i18n/app_localizations.dart';

/// Trade / job role for team employees (foreman-managed).
enum WorkerRole {
  electrician,
  plumber,
  generalWorker,
  carpenter,
  welder,
  helper,
  painter,
  mason,
  hvacTechnician,
}

extension WorkerRoleL10n on WorkerRole {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    WorkerRole.electrician => l10n.workerRoleElectrician,
    WorkerRole.plumber => l10n.workerRolePlumber,
    WorkerRole.generalWorker => l10n.workerRoleGeneralWorker,
    WorkerRole.carpenter => l10n.workerRoleCarpenter,
    WorkerRole.welder => l10n.workerRoleWelder,
    WorkerRole.helper => l10n.workerRoleHelper,
    WorkerRole.painter => l10n.workerRolePainter,
    WorkerRole.mason => l10n.workerRoleMason,
    WorkerRole.hvacTechnician => l10n.workerRoleHvacTechnician,
  };
}
