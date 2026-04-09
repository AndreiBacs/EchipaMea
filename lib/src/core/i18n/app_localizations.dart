import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ro'), Locale('hu')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations not found in context');
    return value!;
  }

  static final Map<String, Map<String, String>> _strings = {
    'en': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Small contractor app',
      'selectRole': 'Select role',
      'continue': 'Continue',
      'language': 'Language',
      'english': 'English',
      'romanian': 'Romanian',
      'hungarian': 'Hungarian',
      'foreman': 'Foreman',
      'worker': 'Worker',
      'roleForemanDescription':
          'Foreman manages crews, assigns jobs, and tracks progress.',
      'roleWorkerDescription':
          'Worker views assigned jobs, updates status, and logs completed work.',
    },
    'ro': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Aplicatie pentru echipe mici de constructori',
      'selectRole': 'Selecteaza rolul',
      'continue': 'Continua',
      'language': 'Limba',
      'english': 'Engleza',
      'romanian': 'Romana',
      'hungarian': 'Maghiara',
      'foreman': 'Sef de echipa',
      'worker': 'Muncitor',
      'roleForemanDescription':
          'Seful de echipa gestioneaza echipele, aloca lucrari si urmareste progresul.',
      'roleWorkerDescription':
          'Muncitorul vede lucrarile alocate, actualizeaza statusul si raporteaza activitatea.',
    },
    'hu': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Alkalmazas kis vallalkozoi csapatoknak',
      'selectRole': 'Szerepkor kivalasztasa',
      'continue': 'Folytatas',
      'language': 'Nyelv',
      'english': 'Angol',
      'romanian': 'Roman',
      'hungarian': 'Magyar',
      'foreman': 'Munkavezeto',
      'worker': 'Munkas',
      'roleForemanDescription':
          'A munkavezeto kezeli a csapatokat, kiosztja a feladatokat es koveti az elorehaladast.',
      'roleWorkerDescription':
          'A munkas latja a kiosztott feladatokat, frissiti az allapotot es jelenti az elvegzett munkat.',
    },
  };

  String _t(String key) {
    return _strings[locale.languageCode]?[key] ?? _strings['en']![key]!;
  }

  String get appTitle => _t('appTitle');
  String get homeTagline => _t('homeTagline');
  String get selectRole => _t('selectRole');
  String get continueLabel => _t('continue');
  String get language => _t('language');
  String get english => _t('english');
  String get romanian => _t('romanian');
  String get hungarian => _t('hungarian');
  String get foreman => _t('foreman');
  String get worker => _t('worker');
  String get roleForemanDescription => _t('roleForemanDescription');
  String get roleWorkerDescription => _t('roleWorkerDescription');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
