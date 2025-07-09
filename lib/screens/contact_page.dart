import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  Future<void> _launchUrl(String url, {launcher.LaunchMode? mode}) async {
    try {
      final uri = Uri.parse(url);
      if (!await launcher.launchUrl(
        uri,
        mode: mode ?? launcher.LaunchMode.platformDefault,
      )) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    const email = 'sanjay13649@gmail.com';
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Yoga App Support',
      },
    );

    try {
      if (!await launcher.launchUrl(emailUri)) {
        throw 'Could not launch email';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app: $e')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(BuildContext context) async {
    const phoneNumber = '+911234567890';
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (!await launcher.launchUrl(phoneUri)) {
        throw 'Could not launch phone';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open phone app: $e')),
        );
      }
    }
  }

  Future<void> _openMaps(BuildContext context) async {
    const location = 'Pollachi';
    final String encodedLocation = Uri.encodeComponent(location);
    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedLocation+yoga+centers'
    );

    try {
      if (!await launcher.launchUrl(
        mapsUri,
        mode: launcher.LaunchMode.externalApplication,
      )) {
        throw 'Could not launch maps';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open maps: $e')),
        );
      }
    }
  }

  Future<void> _openSocialMedia(BuildContext context, String platform) async {
    final Map<String, String> urls = {
      'facebook': 'https://www.facebook.com',
      'instagram': 'https://www.instagram.com',
      'twitter': 'https://www.x.com'
    };

    try {
      final url = urls[platform]!;
      if (!await launcher.launchUrl(
        Uri.parse(url),
        mode: launcher.LaunchMode.externalApplication,
      )) {
        throw 'Could not launch $platform';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $platform: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header with full width
          Container(
            width: double.infinity, // Make container full width
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
                const Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact Cards with proper URLs
                  _buildContactCard(
                    icon: Icons.email,
                    title: 'Email Us',
                    subtitle: 'sanjay13649@gmail.com',
                    onTap: () => _sendEmail(context),
                  ),
                  const SizedBox(height: 16),
                  _buildContactCard(
                    icon: Icons.phone,
                    title: 'Call Us',
                    subtitle: '+91 1234567890',
                    onTap: () => _makePhoneCall(context),
                  ),
                  const SizedBox(height: 16),
                  _buildContactCard(
                    icon: Icons.location_on,
                    title: 'Visit Us',
                    subtitle: 'Pollachi\nTamil Nadu, India',
                    onTap: () => _openMaps(context),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Social Media Section with proper URLs
                  Row(
                    children: [
                      const Text(
                        'Follow Us',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 2,
                        width: 32,
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        onTap: () => _openSocialMedia(context, 'facebook'),
                      ),
                      _buildSocialButton(
                        icon: Icons.camera_alt,
                        label: 'Instagram',
                        onTap: () => _openSocialMedia(context, 'instagram'),
                      ),
                      _buildSocialButton(
                        icon: Icons.close, // X (Twitter) icon
                        label: 'X',
                        onTap: () => _openSocialMedia(context, 'twitter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
