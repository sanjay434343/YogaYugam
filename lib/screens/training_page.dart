import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';  // Add this import
import 'training_detail_page.dart';  // Add this import
import '../models/yoga_models.dart'; // Change this import to use yoga_models.dart
import 'package:qr_flutter/qr_flutter.dart'; // Add this import
import 'dart:async'; // Add this import
import 'package:shimmer/shimmer.dart'; // Add this import
import '../utils/size_config.dart'; // Add this import
import 'package:animations/animations.dart';  // Add this import
import 'package:flutter/services.dart';  // Add this import for haptics

class TrainingPage extends StatefulWidget {
  final String practiceId;
  final String title;
  final String duration;
  final List<String> practices;

  const TrainingPage({
    super.key,
    required this.practiceId,
    required this.title,
    required this.duration,
    required this.practices,
  });

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final DatabaseReference _practiceRef = FirebaseDatabase.instance.ref().child('practice');
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _paymentRef = FirebaseDatabase.instance.ref().child('payment');
  List<Practice> _practices = [];
  bool _isLoading = true;
  String? _error;
  int _totalPoints = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  String? _payeeName;
  String? _upiId;
  final TextEditingController _emailController = TextEditingController();
  Timer? _paymentTimer;
  int _remainingSeconds = 300;  // Initialize here instead of using late
  String? _qrCodeData;
  final TextEditingController _verificationController = TextEditingController();
  String _generatedCode = '';
  String _selectedCategory = 'My Practices';  // Changed default to 'My Practices'
  final List<String> _categories = ['My Practices', 'All Practices'];
  Set<String> _successPracticeIds = {};
  Map<String, String> _practicePaymentStatuses = {}; // Add this new field to store payment statuses

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadPractices();
    _loadUserPoints();
    _loadPaymentDetails();
    _loadPurchaseStatuses(); // Add this line
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _paymentTimer?.cancel();
    _emailController.dispose();
    _verificationController.dispose();
    super.dispose();
  }


  Future<void> _loadPractices() async {
    try {
      _practiceRef.onValue.listen((DatabaseEvent event) {
        final data = event.snapshot.value;
        debugPrint('Raw practice data: $data');

        if (data != null && mounted) {
          if (data is Map) {
            try {
              final practices = <Practice>[];
              data.forEach((key, value) {
                if (value is Map) {
                  // Cast the Map to the correct type
                  final Map<String, dynamic> practiceData = 
                    Map<String, dynamic>.from(value);
                  practices.add(Practice.fromRTDB(practiceData));
                }
              });

              setState(() {
                _practices = practices;
                _isLoading = false;
                _error = null;
              });
            } catch (e) {
              setState(() {
                _error = 'Error parsing practices: $e';
                _isLoading = false;
              });
            }
          }
        } else {
          setState(() {
            _practices = [];
            _isLoading = false;
            _error = 'No practices found';
          });
        }
      }, onError: (error) {
        setState(() {
          _error = 'Database error: $error';
          _isLoading = false;
        });
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _userRef.child('${user.uid}/userdata/totalpoints').onValue.listen((event) {
          if (mounted) {
            setState(() {
              _totalPoints = (event.snapshot.value as int?) ?? 0;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading points: $e');
    }
  }

  Future<void> _loadPaymentDetails() async {
    try {
      final snapshot = await _paymentRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        setState(() {
          _payeeName = data['name']?.toString();
          _upiId = data['upiid']?.toString();
        });
      }
    } catch (e) {
      debugPrint('Error loading payment details: $e');
    }
  }

  Future<void> _loadPurchaseStatuses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      debugPrint('Starting to load purchase statuses for user: ${user.uid}');

      // Reference to practice_payments node
      final practicePaymentsRef = FirebaseDatabase.instance.ref().child('practice_payments');
      
      // Get a single snapshot first to debug the data
      final DataSnapshot snapshot = await practicePaymentsRef.get();
      debugPrint('All payments data: ${snapshot.value}');
      
      // Add an orderByChild filter to get only this user's payments
      final query = practicePaymentsRef.orderByChild('userId').equalTo(user.uid);
      
      query.onValue.listen((event) {
        if (!mounted) return;
        
        debugPrint('Received payment data event');
        final dynamic payments = event.snapshot.value;
        debugPrint('Raw payments data for user: $payments');
        
        if (payments != null) {
          final success = <String>{};
          final statuses = <String, String>{};

          if (payments is Map) {
            payments.forEach((key, value) {
              debugPrint('Processing payment entry: $key -> $value');
              if (value is Map) {
                final practiceId = value['practiceId']?.toString() ?? '';
                final status = value['status']?.toString().toLowerCase() ?? '';
                
                debugPrint('Extracted - PracticeId: $practiceId, Status: $status');
                
                if (practiceId.isNotEmpty) {
                  statuses[practiceId] = status;
                  if (status == 'success') {
                    success.add(practiceId);
                    debugPrint('Added to success: $practiceId');
                  }
                }
              }
            });
          }

          setState(() {
            _practicePaymentStatuses = statuses;
            _successPracticeIds = success;
            debugPrint('Final Status Sets:');
            debugPrint('Success IDs: $_successPracticeIds');
            debugPrint('All Payment Statuses: $_practicePaymentStatuses');
          });
        }

        // Debug available practices
        debugPrint('Available Practices:');
        for (var practice in _practices) {
          debugPrint('Practice ID: ${practice.practiceId}, Name: ${practice.yoga}');
        }
      });

    } catch (e) {
      debugPrint('Error in _loadPurchaseStatuses: $e');
    }
  }

  String _generateUpiUrl(Practice practice) {
    if (_upiId == null || _payeeName == null) {
      return 'Error: Payment details not available';
    }

    // Only generate if not already generated
    if (_qrCodeData == null) {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = _emailController.text.isEmpty ? (user?.email ?? 'No email') : _emailController.text;
      final userId = user?.uid ?? 'unknown';
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final params = {
        'pa': _upiId!.trim(),
        'pn': _payeeName!.trim(),
        'am': practice.price.toStringAsFixed(2),
        'tn': 'Practice: ${practice.yoga}\nUser ID: $userId\nEmail: $userEmail\nTxn: $transactionId',
        'tr': transactionId,
      };
      
      final urlParams = params.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
          
      _qrCodeData = 'upi://pay?$urlParams';
    }
    
    return _qrCodeData!;
  }

  void _startPaymentTimer(BuildContext context, StateSetter setModalState) {
    _paymentTimer?.cancel();
    _remainingSeconds = 300; // Reset to 5 minutes
    
    _paymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (context.mounted) {  // Check if context is still valid
          Navigator.pop(context);
        }
        return;
      }

      if (context.mounted) {  // Check if context is still valid before updating state
        setModalState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = remainingSeconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _remainingSeconds < 60 ? AppColors.secondary.withAlpha(26) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 18,
            color: _remainingSeconds < 60 ? AppColors.secondary : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_remainingSeconds),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _remainingSeconds < 60 ? AppColors.secondary : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _generateVerificationCode() {
    return (1000 + DateTime.now().millisecond % 9000).toString();
  }

  void _handleBuyNow(Practice practice) {
    _verifyPracticeData(practice); // Add this line to verify practice data

    // Add check at the beginning of the method
    if (_successPracticeIds.contains(practice.practiceId)) {
      _navigateToTraining(practice);
      return;
    }

    if (_upiId == null || _payeeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment details not available. Please try again later.')),
      );
      return;
    }

    _generatedCode = _generateVerificationCode();
    bool isVerificationWrong = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Start timer
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startPaymentTimer(context, setModalState);
            });

            return SafeArea(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer and handle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const Spacer(),
                          _buildTimerDisplay(),
                        ],
                      ),
                    ),
                    
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20, 
                          12, 
                          20, 
                          MediaQuery.of(context).viewInsets.bottom + 20
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Practice details - smaller text
                            Text(
                              practice.yoga,
                              style: const TextStyle(
                                fontSize: 20, // Reduced from 24
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6), // Reduced spacing
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '₹${practice.price}',
                                style: const TextStyle(
                                  color: AppColors.textDark, // Changed from AppColors.primary
                                  fontSize: 20, // Reduced from 24
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // QR Code - slightly smaller
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    spreadRadius: 1,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: _generateUpiUrl(practice),
                                    version: QrVersions.auto,
                                    size: 180.0, // Reduced from 200
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_scanner,
                                        color: AppColors.primary,
                                        size: 18, // Reduced size
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Scan with UPI App',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14, // Reduced size
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Payment details - more compact
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Pay to',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _payeeName ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 32,
                                  color: Colors.grey[300],
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        'UPI ID',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _upiId ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Verification section at bottom
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isVerificationWrong 
                                    ? AppColors.secondary.withAlpha(26)
                                    : AppColors.primary.withAlpha(26),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isVerificationWrong
                                      ? AppColors.secondary
                                      : AppColors.primary.withAlpha(51),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Enter Verification Code',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark, // Added color
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _generatedCode,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 6,
                                      color: isVerificationWrong
                                          ? AppColors.secondary
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _verificationController,
                                    decoration: InputDecoration(
                                      hintText: '4-digit code',
                                      errorText: isVerificationWrong
                                          ? 'Invalid code'
                                          : null,
                                      prefixIcon: const Icon(Icons.security),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Submit button
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (_verificationController.text != _generatedCode) {
                                  setModalState(() {
                                    isVerificationWrong = true;
                                  });
                                  return;
                                }

                                try {
                                  // First close the bottom sheet
                                  Navigator.pop(context);
                                  
                                  // Show loading indicator with smaller size
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,  // Fixed width
                                            height: 20, // Fixed height
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2, // Make stroke thinner
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Text('Processing payment...'),
                                        ],
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );

                                  // Submit payment
                                  await _submitPayment(
                                    practice, 
                                    FirebaseAuth.instance.currentUser?.email ?? ''
                                  );

                                  if (context.mounted) {
                                    // Show success message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payment submitted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    // Refresh practices and switch to My Practices tab
                                    setState(() {
                                      _selectedCategory = 'My Practices';
                                    });
                                    await _refreshPractices();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text(
                                'Verify & Submit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _paymentTimer?.cancel();
      _qrCodeData = null;
      _verificationController.clear();
    });
  }

  Future<void> _submitPayment(Practice practice, String email) async {
    _debugCheckPractice(practice); // Add this line to debug practice data
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Create payment reference with practice ID included
      final paymentRef = FirebaseDatabase.instance.ref()
          .child('practice_payments')
          .push();
          
      final paymentData = {
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'practiceId': practice.practiceId,
        'practiceName': practice.yoga,
        'amount': practice.price,
        'purchaseDate': DateTime.now().toIso8601String(),
        'email': email,
        'timestamp': ServerValue.timestamp,
        'status': 'success', // Set directly as success
        'paymentId': paymentRef.key ?? '',
        'paymentMethod': 'UPI',
        'verificationCode': _verificationController.text,
      };

      debugPrint('Submitting payment data: $paymentData');

      // Save payment data
      await paymentRef.set(paymentData);
      
      setState(() {
        _selectedCategory = 'My Practices';
        _successPracticeIds.add(practice.practiceId);
      });

      // Force reload purchase statuses
      await _loadPurchaseStatuses();

    } catch (e) {
      debugPrint('Payment submission error: $e');
      throw Exception('Failed to submit payment: ${e.toString()}');
    }
  }

  Future<void> _refreshPractices() async {
    await _loadPractices();
  }

  void _verifyPracticeData(Practice practice) {
    debugPrint('Verifying practice data:');
    debugPrint('Practice ID: ${practice.practiceId}');
    debugPrint('Practice Name: ${practice.yoga}');
    debugPrint('Practice Price: ${practice.price}');
    if (practice.practiceId.isEmpty) {
      debugPrint('Warning: Practice ID is empty!');
    }
  }

  void _debugCheckPractice(Practice practice) {
    debugPrint('\n=== Practice Details for Payment ===');
    debugPrint('Practice ID: ${practice.practiceId}');
    debugPrint('Name: ${practice.yoga}');
    debugPrint('Price: ${practice.price}');
    debugPrint('Steps Count: ${practice.steps.length}');
    debugPrint('Steps Keys: ${practice.steps.keys.toList()}');
    debugPrint('=============================\n');

    if (practice.practiceId.isEmpty) {
      debugPrint('WARNING: Practice ID is empty! This will cause issues with tracking purchases.');
    }
  }

  void _onTrainingComplete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Great job! Training completed successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    _loadUserPoints(); // Refresh points after completion
  }

  List<Practice> _getFilteredPractices() {
    debugPrint('\n=== Filtering Practices ===');
    debugPrint('Selected Category: $_selectedCategory');
    debugPrint('Total Practices: ${_practices.length}');
    debugPrint('Success IDs: $_successPracticeIds');

    if (_selectedCategory == 'My Practices') {
      final filteredList = _practices.where((practice) {
        debugPrint('\nChecking practice: ${practice.yoga}');
        debugPrint('Practice ID: ${practice.practiceId}');
        final isSuccess = _successPracticeIds.contains(practice.practiceId);
        debugPrint('Is Success: $isSuccess');
        debugPrint('Will be included: $isSuccess');
        return isSuccess;
      }).toList();

      debugPrint('Filtered List Length: ${filteredList.length}');
      return filteredList;
    }

    final unpurchasedList = _practices.where((practice) {
      final isNotPurchased = !_successPracticeIds.contains(practice.practiceId);
      return isNotPurchased;
    }).toList();

    debugPrint('Unpurchased List Length: ${unpurchasedList.length}\n');
    return unpurchasedList;
  }

  // Add this method to manually refresh the status
  Future<void> _refreshPaymentStatus() async {
    await _loadPurchaseStatuses();
    setState(() {
      // Force UI update
    });
  }

  void _handleTabChange(String category) {
    HapticFeedback.lightImpact(); // Add haptic feedback
    setState(() => _selectedCategory = category);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filteredPractices = _getFilteredPractices();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Minimal header with points and tabs
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white.withOpacity(0.8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Points display
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.secondary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_totalPoints pts',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Category tabs with increased corner radius
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategory == category;
                            return GestureDetector(
                              onTap: () => _handleTabChange(category),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.secondary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey[600],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Practice list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshPractices,
                child: _isLoading
                    ? _buildShimmerLoading()
                    : _error != null
                        ? _buildError()
                        : filteredPractices.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: filteredPractices.length,
                                itemBuilder: (context, index) {
                                  final practice = filteredPractices[index];
                                  return _buildPracticeCard(practice, index);
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.self_improvement_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedCategory == 'My Practices'
                ? 'No practices purchased yet'
                : 'No practices available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedCategory == 'My Practices'
                ? 'Purchase a practice to get started'
                : 'All practices have been purchased',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Progress',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Keep Going!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Points Card with blue theme
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withAlpha(77),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Points',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$_totalPoints',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  category,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPracticeList() {
    final filteredPractices = _getFilteredPractices();
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: filteredPractices.length,
      itemBuilder: (context, index) {
        final practice = filteredPractices[index];
        
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.5, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Interval(
              index * 0.1,
              0.6 + index * 0.1,
              curve: Curves.easeOutCubic,
            ),
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeController,
              curve: Interval(
                index * 0.1,
                0.6 + index * 0.1,
                curve: Curves.easeOut,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  final isSuccess = _successPracticeIds.contains(practice.practiceId);

                  if (isSuccess) {
                    _navigateToTraining(practice);
                  } else {
                    _handleBuyNow(practice);
                  }
                },
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.accent,
                        AppColors.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withAlpha(77),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getPracticeIcon(practice.yoga.toLowerCase()),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  practice.yoga,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${practice.steps.length} poses · ${_formatDuration(practice.steps.length * 30)} mins',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(204),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      if (index == 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                color: Colors.orange,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Most Popular',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Add price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '₹${practice.price}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Add status badge
                      if (_successPracticeIds.contains(practice.practiceId))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PURCHASED',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this helper method
  bool _hasPurchasedPractice(String practiceId) {
    return _successPracticeIds.contains(practiceId);
  }

  IconData _getPracticeIcon(String practiceName) {
    if (practiceName.contains('surya')) return Icons.wb_sunny_rounded;
    if (practiceName.contains('meditation')) return Icons.self_improvement_rounded;
    if (practiceName.contains('stretch')) return Icons.accessibility_new_rounded;
    return Icons.fitness_center_rounded;
  }

  String _formatDuration(int minutes) {
    return '${(minutes / 60).floor()}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  void _navigateToTraining(Practice practice) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: TrainingDetailPage(
              title: practice.yoga,
              steps: practice.steps.values.toList(), // Simplified since YogaStep is now the same type
              duration: practice.steps.values.fold(
                0,
                (sum, step) => sum + (int.tryParse(step.duration.replaceAll(RegExp(r'\D'), '')) ?? 0),
              ),
              onComplete: _onTrainingComplete,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.withAlpha(204)),
          const SizedBox(height: 16),
          Text(_error ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadPractices(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeCard(Practice practice, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double fontSize = screenWidth < 360 ? 14 : 16;
    final double iconSize = screenWidth < 360 ? 18 : 20;
    final double padding = screenWidth < 360 ? 12 : 16;
    
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.getProportionateScreenHeight(10)),
      child: OpenContainer(
        transitionDuration: const Duration(milliseconds: 500),
        openBuilder: (context, _) => TrainingDetailPage(
          title: practice.yoga,
          steps: practice.steps.values.toList(),
          duration: practice.steps.values.fold(
            0,
            (sum, step) => sum + (int.tryParse(step.duration.replaceAll(RegExp(r'\D'), '')) ?? 0),
          ),
          onComplete: _onTrainingComplete,
        ),
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppColors.secondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        closedElevation: 2,
        closedColor: Colors.white,
        closedBuilder: (context, openContainer) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_successPracticeIds.contains(practice.practiceId)) {
                openContainer();
              } else {
                _handleBuyNow(practice);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(padding * 0.7),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.self_improvement_rounded, // Changed to yoga icon
                          color: AppColors.secondary,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: padding),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              practice.yoga,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: padding * 0.25),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: iconSize * 0.7,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: padding * 0.25),
                                Text(
                                  '${practice.steps.length * 30} min',
                                  style: TextStyle(
                                    fontSize: fontSize * 0.75,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(width: padding * 0.75),
                                Icon(
                                  Icons.self_improvement_rounded, // Changed to yoga icon
                                  size: iconSize * 0.7,
                                  color: Colors.grey[600],
                                ),
                                SizedBox(width: padding * 0.25),
                                Text(
                                  '${practice.steps.length} poses',
                                  style: TextStyle(
                                    fontSize: fontSize * 0.75,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_successPracticeIds.contains(practice.practiceId))
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: iconSize,
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 0.75,
                            vertical: padding * 0.375,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(padding),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '₹${practice.price}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize * 0.875,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleCardTap(Practice practice) {
    final isSuccess = _successPracticeIds.contains(practice.practiceId);

    if (isSuccess) {
      _navigateToTraining(practice);
    } else {
      _handleBuyNow(practice);
    }
  }

  Widget _buildShimmerLoading() {
    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(20),
      children: List.generate(3, (index) => _buildShimmerCard()),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 100,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}