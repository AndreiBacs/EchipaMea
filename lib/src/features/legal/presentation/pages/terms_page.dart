import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  static const routePath = '/terms';
  static const routeName = 'terms';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms and Conditions')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms and Conditions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              'By using EchipaMea, you agree to use the app only for lawful work coordination and team management.',
            ),
            SizedBox(height: 10),
            Text(
              '1. Accounts and Roles\n'
              'Foreman accounts can manage projects, teams, and clients. Worker accounts can access assigned tasks only.',
            ),
            SizedBox(height: 10),
            Text(
              '2. Data Usage\n'
              'Project and employee data should be accurate and updated by authorized users only.',
            ),
            SizedBox(height: 10),
            Text(
              '3. Privacy\n'
              'Do not upload sensitive personal data unless required by your legal obligations and company policy.',
            ),
            SizedBox(height: 10),
            Text(
              '4. QR Login\n'
              'QR login credentials must be used only by the intended employee and should not be shared.',
            ),
            SizedBox(height: 10),
            Text(
              '5. Changes\n'
              'These terms may be updated over time. Continued use of the app means you accept future updates.',
            ),
            SizedBox(height: 10),
            Text(
              '6. GDPR\n'
              'EchipaMea processes personal data in line with the General Data Protection Regulation (EU) 2016/679. '
              'Users have the right to access, rectify, or erase their personal data and to request restrictions on processing, '
              'subject to applicable legal obligations.',
            ),
          ],
        ),
      ),
    );
  }
}
