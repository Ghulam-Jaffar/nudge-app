import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for Nudge',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: February 2026',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              theme,
              'Introduction',
              'Nudge ("we", "our", or "us") is committed to protecting your privacy. '
                  'This Privacy Policy explains how we collect, use, and safeguard your information '
                  'when you use our mobile application.',
            ),
            _buildSection(
              theme,
              'Information We Collect',
              'We collect the following information:\n\n'
                  '• Account Information: Email address and display name when you create an account\n'
                  '• Profile Information: Your username (handle) that you choose\n'
                  '• Reminder Data: The reminders and tasks you create, including titles, descriptions, and due dates\n'
                  '• Shared Spaces: Information about spaces you create or join, and other members you interact with',
            ),
            _buildSection(
              theme,
              'How We Use Your Information',
              'We use your information to:\n\n'
                  '• Provide and maintain the Nudge app\n'
                  '• Send you notifications for your reminders\n'
                  '• Enable sharing features with other users\n'
                  '• Improve our services',
            ),
            _buildSection(
              theme,
              'Data Storage',
              'Your data is securely stored using Google Firebase services. '
                  'We use industry-standard security measures to protect your information.',
            ),
            _buildSection(
              theme,
              'Data Sharing',
              'We do not sell your personal information. Your data is only shared:\n\n'
                  '• With other users you explicitly invite to your shared spaces\n'
                  '• With service providers (Firebase) necessary to operate the app\n'
                  '• When required by law',
            ),
            _buildSection(
              theme,
              'Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Delete your account and associated data\n'
                  '• Opt out of notifications\n'
                  '• Export your data',
            ),
            _buildSection(
              theme,
              'Data Retention',
              'We retain your data for as long as your account is active. '
                  'If you delete your account, your personal data will be removed from our systems.',
            ),
            _buildSection(
              theme,
              'Children\'s Privacy',
              'Nudge is not intended for children under 13. '
                  'We do not knowingly collect personal information from children under 13.',
            ),
            _buildSection(
              theme,
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. '
                  'We will notify you of any changes by posting the new Privacy Policy in the app.',
            ),
            _buildSection(
              theme,
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                  'nudgeapp.reminder@gmail.com',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
