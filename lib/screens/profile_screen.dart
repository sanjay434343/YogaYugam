import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'settings_page.dart';
import 'contact_page.dart';
import 'privacy_policy_page.dart';
import 'ranking_page.dart';
import 'package:animations/animations.dart';
import 'practice_history_page.dart'; // Add this import

const Duration _kDuration = Duration(milliseconds: 300);
const double _kClosedElevation = 0.0;
const double _kOpenElevation = 0.0;
const ContainerTransitionType _kTransitionType = ContainerTransitionType.fade;

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();
  Map<String, dynamic>? _userData;
  int _totalPoints = 0;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userRef = _database.child('users/${user.uid}');
      
      // Listen to totalpoints
      userRef.child('userdata/totalpoints').onValue.listen((event) {
        if (mounted) {
          setState(() {
            _totalPoints = (event.snapshot.value as int?) ?? 0;
          });
        }
      });
      
      // Get name directly from root level of user node
      userRef.child('name').onValue.listen((event) {
        if (mounted && event.snapshot.value != null) {
          setState(() {
            _userData = {'name': event.snapshot.value.toString()};
          });
          debugPrint('Loaded user name: ${event.snapshot.value}');
        }
      });
    }
  }

  Future<void> _updateUserName(String newName) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Update name at root level of user node
        await _database.child('users/${user.uid}/name').set(newName);
        
        setState(() {
          _userData = {'name': newName};
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating name: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showNameEditDialog() {
    final user = _auth.currentUser;
    final currentName = _userData?['name'] ?? user?.email?.split('@')[0] ?? 'User';
    _nameController.text = currentName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                _updateUserName(_nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  Widget _buildPointsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.9),
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Total Points',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$_totalPoints',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 24),
                const SizedBox(height: 4),
                Text(
                  '+${_totalPoints ~/ 10}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String email) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Gradient Background with Pattern
        Container(
          height: 200, // Increased height
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(50),
            ),
          ),
          child: Stack(
            children: [
              // Add decorative pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: CustomPaint(
                    painter: PatternPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Profile Content
        Positioned(
          top: 100,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[100],
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.1),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Edit Button with animations
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: _showNameEditDialog,
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: 0.9 + (0.1 * value),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 16),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    required Widget destination,
    bool isSignOut = false,
  }) {
    if (isSignOut) {
      return OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: _kDuration,
        openBuilder: (context, _) => SignOutScreen(
          onSignOut: () {
            Navigator.pop(context);
            _signOut();
          },
          onCancel: () => Navigator.pop(context),
        ),
        closedElevation: _kClosedElevation,
        openElevation: _kOpenElevation,
        closedColor: Colors.transparent,
        openColor: Colors.transparent,
        middleColor: Colors.transparent,
        closedBuilder: (context, openContainer) => ListTile(
          leading: AnimatedContainer(
            duration: _kDuration,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary),
          ),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.secondary,
          ),
          onTap: openContainer,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OpenContainer(
        transitionType: _kTransitionType,
        transitionDuration: _kDuration,
        openBuilder: (context, _) => destination,
        closedElevation: _kClosedElevation, // Updated from _kElevation
        openElevation: _kOpenElevation, // Updated from _kElevation
        closedColor: Colors.transparent,
        openColor: Colors.transparent,
        middleColor: Colors.transparent,
        closedBuilder: (context, openContainer) => ListTile(
          leading: AnimatedContainer(
            duration: _kDuration,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.secondary),
          ),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle) : null,
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.secondary,
          ),
          onTap: openContainer,
        ),
      ),
    );
  }

  // Update the sign out settings card
  Widget _buildSettingsCard(List<Map<String, dynamic>> items) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSignOut = item['title'] == 'Sign Out'; // Check if it's the sign out button
          
          return Column(
            children: [
              _buildListTile(
                icon: item['icon'],
                title: item['title'],
                iconColor: AppColors.secondary,
                onTap: item['onTap'],
                destination: item['destination'],
                isSignOut: isSignOut, // Pass the flag
              ),
              if (index < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.secondary.withOpacity(0.2),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = _auth.currentUser;
    final email = user?.email ?? 'No email';
    final name = _userData?['name'] ?? email.split('@')[0];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(name, email),
            const SizedBox(height: 95),
            _buildPointsCard(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Practice & Rankings
                  _buildSettingsCard([
                    {
                      'icon': Icons.history,
                      'title': 'Practice History',
                      'onTap': () {},
                      'destination': const PracticeHistoryPage(), // Changed from ProgressScreen
                    },
                    {
                      'icon': Icons.leaderboard,
                      'title': 'Rankings',
                      'onTap': () {},
                      'destination': const RankingPage(),
                    },
                  ]),
                  const SizedBox(height: 16),
                  // Help & Support
                  _buildSettingsCard([
                    {
                      'icon': Icons.contact_support,
                      'title': 'Contact Us',
                      'onTap': () {},
                      'destination': const ContactPage(),
                    },
                    {
                      'icon': Icons.privacy_tip,
                      'title': 'Privacy Policy',
                      'onTap': () {},
                      'destination': const PrivacyPolicyPage(),
                    },
                  ]),
                  const SizedBox(height: 16),
                  // Settings & Sign Out
                  _buildSettingsCard([
                    {
                      'icon': Icons.settings,
                      'title': 'Settings',
                      'onTap': () {},
                      'destination': const SettingsPage(),
                    },
                    {
                      'icon': Icons.exit_to_app,
                      'title': 'Sign Out',
                      'onTap': () {}, // Empty onTap since we handle it in _buildListTile
                      'destination': const SizedBox(),
                      'isSignOut': true, // Add this flag
                    },
                  ]),
                  const SizedBox(height: 24),
                 
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// Add this new widget for sign out screen
class SignOutScreen extends StatelessWidget {
  final VoidCallback onSignOut;
  final VoidCallback onCancel;

  const SignOutScreen({
    super.key, 
    required this.onSignOut,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.secondary),
          onPressed: onCancel,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 64,
                color: AppColors.secondary.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.secondary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: onSignOut,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
