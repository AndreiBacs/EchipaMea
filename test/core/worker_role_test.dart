import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echipa_mea/src/core/domain/entities/worker_role.dart';
import 'package:echipa_mea/src/core/i18n/app_localizations.dart';

void main() {
  group('WorkerRole.localizedLabel', () {
    final en = AppLocalizations(const Locale('en'));
    final ro = AppLocalizations(const Locale('ro'));

    test('enum has exactly 9 values', () {
      expect(WorkerRole.values.length, 9);
    });

    group('English labels', () {
      test('electrician maps to correct key', () {
        expect(WorkerRole.electrician.localizedLabel(en), 'Electrician');
      });

      test('plumber maps to correct key', () {
        expect(WorkerRole.plumber.localizedLabel(en), 'Plumber');
      });

      test('generalWorker maps to correct key', () {
        expect(WorkerRole.generalWorker.localizedLabel(en), 'General worker');
      });

      test('carpenter maps to correct key', () {
        expect(WorkerRole.carpenter.localizedLabel(en), 'Carpenter');
      });

      test('welder maps to correct key', () {
        expect(WorkerRole.welder.localizedLabel(en), 'Welder');
      });

      test('helper maps to correct key', () {
        expect(WorkerRole.helper.localizedLabel(en), 'Helper');
      });

      test('painter maps to correct key', () {
        expect(WorkerRole.painter.localizedLabel(en), 'Painter');
      });

      test('mason maps to correct key', () {
        expect(WorkerRole.mason.localizedLabel(en), 'Mason');
      });

      test('hvacTechnician maps to correct key', () {
        expect(WorkerRole.hvacTechnician.localizedLabel(en), 'HVAC technician');
      });
    });

    group('Romanian labels', () {
      test('electrician maps to correct key', () {
        expect(WorkerRole.electrician.localizedLabel(ro), 'Electrician');
      });

      test('plumber maps to correct key', () {
        expect(WorkerRole.plumber.localizedLabel(ro), 'Instalator');
      });

      test('generalWorker maps to correct key', () {
        expect(WorkerRole.generalWorker.localizedLabel(ro), 'Muncitor general');
      });

      test('carpenter maps to correct key', () {
        expect(WorkerRole.carpenter.localizedLabel(ro), 'Tamplar');
      });

      test('welder maps to correct key', () {
        expect(WorkerRole.welder.localizedLabel(ro), 'Sudor');
      });

      test('helper maps to correct key', () {
        expect(WorkerRole.helper.localizedLabel(ro), 'Ajutor');
      });

      test('painter maps to correct key', () {
        expect(WorkerRole.painter.localizedLabel(ro), 'Zugrav');
      });

      test('mason maps to correct key', () {
        expect(WorkerRole.mason.localizedLabel(ro), 'Zidar');
      });

      test('hvacTechnician maps to correct key', () {
        expect(WorkerRole.hvacTechnician.localizedLabel(ro), 'Tehnician HVAC');
      });
    });

    test('each value returns a non-empty label in every locale', () {
      for (final l10n in [en, ro]) {
        for (final role in WorkerRole.values) {
          expect(
            role.localizedLabel(l10n),
            isNotEmpty,
            reason: '${role.name} should have a non-empty label',
          );
        }
      }
    });
  });
}
