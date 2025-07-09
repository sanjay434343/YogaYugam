import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PollCard extends StatefulWidget {
  final bool isInDrawer;

  const PollCard({
    super.key,
    this.isInDrawer = false,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  final database = FirebaseDatabase.instance.ref();
  final auth = FirebaseAuth.instance;
  Map<String, dynamic>? pollData;
  String? selectedOption;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    loadPollData();
    checkIfSubmitted();
  }

  Future<void> checkIfSubmitted() async {
    final user = auth.currentUser;
    if (user != null) {
      final response = await database
          .child('poll/responses/${user.uid}')
          .once();
      if (response.snapshot.value != null) {
        setState(() {
          _isSubmitted = true;
        });
      }
    }
  }

  Future<void> loadPollData() async {
    try {
      final pollRef = database.child('poll');
      
      pollRef.onValue.listen(
        (event) {
          if (!mounted) return;
          
          try {
            if (event.snapshot.value != null) {
              final rawData = event.snapshot.value as Map<Object?, Object?>;
              
              // Handle options correctly whether it's a List or Map
              final optionsData = rawData['options'];
              List<String> convertedOptions;
              
              if (optionsData is List) {
                // If options is a List, convert directly
                convertedOptions = optionsData
                    .where((item) => item != null)
                    .map((item) => item.toString())
                    .toList();
              } else if (optionsData is Map) {
                // If options is a Map, extract values
                convertedOptions = optionsData.values
                    .where((item) => item != null)
                    .map((item) => item.toString())
                    .toList();
              } else {
                convertedOptions = [];
              }

              final convertedData = {
                'question': rawData['question']?.toString() ?? 'How often do you practice yoga?',
                'options': convertedOptions,
              };

              setState(() {
                pollData = convertedData;
              });
            }
          } catch (e) {
            print('Error processing poll data: $e');
          }
        },
        onError: (error) {
          print('Error listening to poll: $error');
        },
      );

      // Check if user has already responded
      final user = auth.currentUser;
      if (user != null) {
        try {
          final response = await database
              .child('poll/responses/${user.uid}')
              .once();
              
          if (response.snapshot.value != null) {
            final responseData = response.snapshot.value as Map<Object?, Object?>;
            setState(() {
              selectedOption = responseData['option']?.toString();
              _isSubmitted = true;
            });
          }
        } catch (e) {
          print('Error loading user response: $e');
        }
      }
    } catch (e) {
      print('Error in loadPollData: $e');
    }
  }

  Future<void> submitPoll() async {
    if (selectedOption == null) return;

    final user = auth.currentUser;
    if (user != null) {
      try {
        // Update to match the rules structure
        await database
            .child('poll/responses/${user.uid}')
            .set({
              'option': selectedOption!, // Store as string
              'timestamp': DateTime.now().toIso8601String(),
            });
            
        setState(() {
          _isSubmitted = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your response!'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          );
          
          if (widget.isInDrawer) {
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        print('Error submitting poll: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit response: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted && !widget.isInDrawer) {
      return const SizedBox.shrink();
    }

    if (pollData == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ),
        ),
      );
    }

    final question = pollData?['question'] ?? 'How often do you practice yoga?';
    final options = pollData?['options'] as List<String>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.poll_outlined, 
                        color: AppColors.primary,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Quick Poll',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isInDrawer)
                    TextButton(
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                      child: const Text('Answer in drawer'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(options.length, (index) => RadioListTile<String>(
                title: Text(options[index]),
                value: index.toString(),
                groupValue: selectedOption,
                activeColor: AppColors.primary,
                onChanged: _isSubmitted ? null : (String? value) {
                  setState(() {
                    selectedOption = value;
                  });
                },
              )),
              if (!_isSubmitted && widget.isInDrawer) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedOption == null ? null : submitPoll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
}
