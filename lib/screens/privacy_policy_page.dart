import 'package:flutter/material.dart';
import '../theme/colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection(
                  title: 'Information We Collect',
                  icon: Icons.info_outline,
                  content: 'We collect information that you provide directly to us, including name, email address, and workout data.',
                ),
                _buildSection(
                  title: 'How We Use Your Information',
                  icon: Icons.security,
                  content: 'Your information is used to provide and improve our services, personalize your experience, and send important updates.',
                ),
                _buildSection(
                  title: 'Data Security',
                  icon: Icons.shield_outlined,
                  content: 'We implement appropriate security measures to protect your personal information from unauthorized access or disclosure.',
                ),
                _buildSection(
                  title: 'Third-Party Services',
                  icon: Icons.share_outlined,
                  content: 'We may use third-party services that collect information about you. These services have their own privacy policies.',
                ),
                _buildSection(
                  title: 'Your Rights',
                  icon: Icons.gavel_outlined,
                  content: 'You have the right to access, update, or delete your personal information. Contact us for assistance.',
                ),
                _buildSection(
                  title: 'Updates to Policy',
                  icon: Icons.update,
                  content: 'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy.',
                ),
                const SizedBox(height: 20),
                _buildContactInfo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData().copyWith(
          dividerColor: Colors.transparent, // This removes the divider line
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              content,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions or Concerns?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'If you have any questions about our Privacy Policy, please contact us:',
            style: TextStyle(color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          _buildContactRow(Icons.email_outlined, 'sanjay13649@gmail.com'),
          const SizedBox(height: 8),
          _buildContactRow(Icons.location_on_outlined, 'Pollachi, Tamil Nadu'),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}