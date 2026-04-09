import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const routePath = '/terms';
  static const routeName = 'terms';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsAndConditions)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.termsAndConditions,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(l10n.termsIntro),
            const SizedBox(height: 10),
            Text(l10n.termsSection1),
            const SizedBox(height: 10),
            Text(l10n.termsSection2),
            const SizedBox(height: 10),
            Text(l10n.termsSection3),
            const SizedBox(height: 10),
            Text(l10n.termsSection4),
            const SizedBox(height: 10),
            Text(l10n.termsSection5),
            const SizedBox(height: 10),
            Text(l10n.termsSection6),
          ],
        ),
      ),
    );
  }
}
