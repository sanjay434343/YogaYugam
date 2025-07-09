import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final List<Map<String, dynamic>> _rankings = [];
  bool _isLoading = true;
  String _currentUserId = '';
  int _currentUserRank = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    try {
      final usersRef = FirebaseDatabase.instance.ref().child('users');
      final snapshot = await usersRef.get();

      if (snapshot.value != null && snapshot.value is Map) {
        final List<Map<String, dynamic>> rankings = [];
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        data.forEach((userId, userData) {
          if (userData is Map) {
            final userMap = Map<String, dynamic>.from(userData);
            final points = userMap['userdata']?['totalpoints'] as int? ?? 0;
            // Use name directly from user data, fallback to email if name is not available
            final name = userMap['name'] as String? ?? 
                        userMap['email'] as String? ??
                        'Unknown User';
            
            rankings.add({
              'userId': userId,
              'name': name,
              'points': points,
            });
          }
        });

        // Sort by points in descending order
        rankings.sort((a, b) => b['points'].compareTo(a['points']));

        // Find current user's rank
        _currentUserRank = rankings.indexWhere((r) => r['userId'] == _currentUserId) + 1;

        setState(() {
          _rankings.clear();
          _rankings.addAll(rankings);
          _isLoading = false;
        });

        // Debug print to verify data
        debugPrint('Rankings loaded:');
        for (var rank in rankings) {
          debugPrint('User: ${rank['name']}, Points: ${rank['points']}');
        }
      }
    } catch (e) {
      debugPrint('Error loading rankings: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
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
            'Leaderboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 30),
          if (_rankings.isNotEmpty) _buildTopThree(),
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_rankings.length > 1) _buildTopUser(_rankings[1], 2, 0.85),
        _buildTopUser(_rankings[0], 1, 1.0),
        if (_rankings.length > 2) _buildTopUser(_rankings[2], 3, 0.7),
      ],
    );
  }

  Widget _buildTopUser(Map<String, dynamic> user, int rank, double scale) {
    final isCurrentUser = user['userId'] == _currentUserId;
    const baseHeight = 140.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getMedalColor(rank),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getMedalColor(rank).withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 30 * scale,
            backgroundColor: Colors.white,
            child: Text(
              user['name'][0].toUpperCase(),
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${user['points']} pts',
            style: TextStyle(
              color: isCurrentUser ? AppColors.primary : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user['name'],
          style: TextStyle(
            color: Colors.white,
            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            fontSize: 14 * scale,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Container(
          height: baseHeight * scale,
          width: 60 * scale,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Center(
            child: Icon(
              _getMedalIcon(rank),
              color: _getMedalColor(rank),
              size: 24 * scale,
            ),
          ),
        ),
      ],
    );
  }

  Color _getMedalColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[300]!;
      case 3:
        return Colors.brown[300]!;
      default:
        return Colors.grey;
    }
  }

  IconData _getMedalIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
      case 3:
        return Icons.workspace_premium;
      default:
        return Icons.stars;
    }
  }

  Widget _buildRankList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: _rankings.length - 3,
      itemBuilder: (context, index) {
        final rank = index + 4;
        final user = _rankings[index + 3];
        final isCurrentUser = user['userId'] == _currentUserId;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Material(
            color: isCurrentUser ? AppColors.primary.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentUser ? AppColors.primary : Colors.grey[200]!,
                  width: isCurrentUser ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentUser ? AppColors.primary.withOpacity(0.2) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: isCurrentUser ? AppColors.primary : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isCurrentUser ? AppColors.primary.withOpacity(0.2) : Colors.grey[200],
                    child: Text(
                      user['name'][0].toUpperCase(),
                      style: TextStyle(
                        color: isCurrentUser ? AppColors.primary : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user['name'],
                      style: TextStyle(
                        fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                        color: isCurrentUser ? AppColors.primary : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${user['points']} pts',
                      style: TextStyle(
                        color: isCurrentUser ? AppColors.primary : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildRankList()),
              ],
            ),
    );
  }
}
