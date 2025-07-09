import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';

class PollScreen extends StatefulWidget {
  const PollScreen({super.key});

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  Map<String, dynamic> _polls = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    try {
      final snapshot = await _database.child('poll').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        final processedPolls = <String, Map<String, dynamic>>{};
        
        data.forEach((key, value) {
          if (value is Map<Object?, Object?>) {
            final pollId = key.toString();
            final pollData = <String, dynamic>{};
            
            // Process options
            if (value['options'] is List) {
              final options = (value['options'] as List)
                  .where((item) => item != null)
                  .map((item) => item.toString())
                  .toList();
              pollData['options'] = options;
            } else {
              pollData['options'] = <String>[];
            }
            
            // Process question
            pollData['question '] = value['question ']?.toString() ?? 'No question';
            
            // Process responses
            if (value['responses'] is Map) {
              final responses = Map<String, dynamic>.from(
                (value['responses'] as Map).map((key, value) => 
                  MapEntry(key.toString(), value as dynamic)
                )
              );
              pollData['responses'] = responses;
            } else {
              pollData['responses'] = <String, dynamic>{};
            }
            
            processedPolls[pollId] = pollData;
          }
        });

        if (mounted) {
          setState(() {
            _polls = processedPolls;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _polls = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading polls: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitResponse(String pollId, int optionIndex) async {
    if (!mounted) return;
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _database
          .child('poll/$pollId/responses/${user.uid}')
          .set(optionIndex);

      if (!mounted) return;
      await _loadPolls();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting response: $e')),
      );
    }
  }

  Widget _buildPollCard(String pollId, Map<String, dynamic> pollData) {
    final question = pollData['question '] ?? 'No question'; // Note the space in 'question '
    final options = List<String>.from((pollData['options'] as List?)?.where((x) => x != null) ?? []);
    final responses = pollData['responses'] as Map<String, dynamic>?;
    final userResponse = responses?[_auth.currentUser?.uid];
    final totalResponses = responses?.length ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(13), // Changed from withOpacity
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Updated Question Section - Removed gradient background
              Text(
                question,
                style: const TextStyle(
                  fontSize: 22, // Increased size
                  fontWeight: FontWeight.w800, // Made bolder
                  color: Colors.black,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24), // Increased spacing
              // Updated Options Section with proper margins
              ...options.asMap().entries.map((entry) {
                final index = entry.key + 1; // +1 because options[0] is null
                final option = entry.value;
                final isSelected = userResponse == index;
                final responseCount = responses?.values
                    .where((response) => response == index)
                    .length ?? 0;
                final percentage = totalResponses > 0 
                    ? (responseCount / totalResponses * 100).round()
                    : 0;

                return Padding(
                  padding: const EdgeInsets.only(
                    left: 8, // Added left margin
                    bottom: 12,
                  ),
                  child: InkWell(
                    onTap: userResponse == null 
                        ? () => _submitResponse(pollId, index)
                        : null,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20, // Increased horizontal padding
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              )
                            : null,
                        color: isSelected 
                            ? null
                            : Colors.grey.withOpacity(0.05),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.transparent
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (userResponse != null)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    isSelected 
                                        ? Colors.white.withOpacity(0.2)
                                        : AppColors.primary.withOpacity(0.1),
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                    color: isSelected 
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              if (userResponse != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected 
                                        ? Colors.white.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$percentage%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected 
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // Total Responses Section
              if (userResponse != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalResponses ${totalResponses == 1 ? 'response' : 'responses'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daily Polls',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _polls.isEmpty
                  ? const Center(child: Text('No polls available'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: _polls.entries
                          .map((entry) => _buildPollCard(entry.key, entry.value))
                          .toList(),
                    ),
    );
  }
}
