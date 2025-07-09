import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class PracticeHistoryPage extends StatefulWidget {
  const PracticeHistoryPage({super.key});

  @override
  State<PracticeHistoryPage> createState() => _PracticeHistoryPageState();
}

class _PracticeHistoryPageState extends State<PracticeHistoryPage> {
  // Change to List<dynamic> to handle mixed types
  final List<dynamic> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseDatabase.instance.ref()
            .child('users/${user.uid}/points_history');
        
        final snapshot = await ref.orderByChild('timestamp').once();
        
        if (snapshot.snapshot.value != null) {
          final activities = <Map<String, dynamic>>[];
          final data = snapshot.snapshot.value as Map<dynamic, dynamic>;
          
          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              final activityMap = Map<String, dynamic>.from(
                value.map((key, value) => MapEntry(key.toString(), value))
              );
              activities.add(activityMap);
            }
          });

          // Sort activities by timestamp in descending order
          activities.sort((a, b) => 
            (b['exactTime']?.toString() ?? '').compareTo(a['exactTime']?.toString() ?? ''));

          setState(() {
            _activities.clear();
            _activities.addAll(activities);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    // Update this method to use totalpoints from userdata instead of calculating from history
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref()
          .child('users/${FirebaseAuth.instance.currentUser?.uid}/userdata/totalpoints')
          .onValue,
      builder: (context, snapshot) {
        final totalPoints = (snapshot.data?.snapshot.value as int?) ?? 0;
        final totalPractices = _activities.length;
        
        return Container(
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
              // Add back button
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
                'Practice History',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Points',
                      '$totalPoints',
                      Icons.emoji_events_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Practices',
                      '$totalPractices',
                      Icons.fitness_center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No practice history yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Group activities by date
    final groupedActivities = <String, List<Map<String, dynamic>>>{};
    for (var activity in _activities) {
      final date = activity['timestamp']?.toString().split('T')[0] ?? '';
      groupedActivities.putIfAbsent(date, () => []).add(activity);
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: groupedActivities.length,
      itemBuilder: (context, index) {
        final date = groupedActivities.keys.elementAt(index);
        final activities = groupedActivities[date]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                _formatDate(date),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            ...activities.map((activity) => _buildActivityCard(activity)),
          ],
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (DateUtils.isSameDay(date, now)) {
      return 'Today';
    } else if (DateUtils.isSameDay(date, yesterday)) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, y').format(date);
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final time = DateTime.parse(activity['exactTime'] ?? '');
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.fitness_center,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          activity['activity'] ?? 'Unknown Practice',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          DateFormat('h:mm a').format(time),
          style: TextStyle(color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '+${activity['points']} pts',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildActivityList(),
          ),
        ],
      ),
    );
  }
}