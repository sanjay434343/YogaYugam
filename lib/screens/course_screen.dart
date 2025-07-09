import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../screens/video_player_screen.dart';  // Fixed import path
import '../services/auth_service.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/shimmer_loading.dart';
import 'dart:math';
// Add Course model import
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_storage_service.dart';
import 'package:animations/animations.dart'; // Import animations package
import 'package:flutter/services.dart';  // Add this import for HapticFeedback

// Add animation constants
const Duration _kAnimationDuration = Duration(milliseconds: 300);
const double _kOpenScale = 1.0;
const double _kClosedScale = 0.9;

// Move the CardTransform class here
class CardTransform {
  static Matrix4 transform(bool isPressed) {
    return Matrix4.identity()
      ..scale(isPressed ? 0.95 : 1.0)
      ..translate(0.0, isPressed ? 2.0 : 0.0);
  }
}

// Add this new widget at the top level of the file
class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double gap;

  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 32.0, // Gap between the end and start of text
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Animation<double> _animation;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Adjust speed here
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final double maxScrollExtent = _scrollController.position.maxScrollExtent;
        _animation = Tween<double>(
          begin: 0.0,
          end: -maxScrollExtent - widget.gap,
        ).animate(_animationController);

        _animation.addListener(() {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(-_animation.value % (maxScrollExtent + widget.gap));
          }
        });

        if (maxScrollExtent > 0) {
          _animationController.repeat();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          SizedBox(width: widget.gap),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}

class Course {
  final int id;  // Change to int
  final String name;
  final String description;
  final String duration;
  final String image;
  final String src;
  final int price;  // Change to int

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.image,
    required this.src,
    required this.price,
  });

  factory Course.fromRTDB(Map<dynamic, dynamic> map) {
    try {
      // Safely convert id to int
      int parseId() {
        var rawId = map['id'];
        if (rawId is int) return rawId;
        if (rawId is String) return int.tryParse(rawId) ?? 0;
        return 0;
      }

      // Safely convert price to int
      int parsePrice() {
        var rawPrice = map['price'];
        if (rawPrice is int) return rawPrice;
        if (rawPrice is String) return int.tryParse(rawPrice) ?? 0;
        if (rawPrice is double) return rawPrice.toInt();
        return 0;
      }

      // Add validation for required fields
      final name = map['name']?.toString() ?? '';
      final image = map['image']?.toString() ?? '';
      final duration = map['duration']?.toString() ?? '';
      
      if (name.isEmpty || image.isEmpty || duration.isEmpty) {
        throw const FormatException('Missing required course fields');
      }

      return Course(
        id: parseId(),
        name: name,
        description: map['description']?.toString() ?? '',
        duration: duration,
        image: image,
        src: map['src']?.toString() ?? '',
        price: parsePrice(),
      );
    } catch (e) {
      debugPrint('Error parsing course data: $e');
      rethrow;
    }
  }
}

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final DatabaseReference _coursesRef = FirebaseDatabase.instance.ref().child('courses');
  final AuthService _authService = AuthService();
  List<Course> _courses = [];
  bool _isLoading = true;
  String? _error;
  late AnimationController _animationController;
  final List<String> _categories = ['My Courses', 'All'];
  String _selectedCategory = 'My Courses';  // Set default to My Courses
  final DatabaseReference _paymentRef = FirebaseDatabase.instance.ref().child('payment');
  String? _payeeName;
  String? _upiId;
  final TextEditingController _emailController = TextEditingController();
  Timer? _paymentTimer;
  int _remainingSeconds = 300;  // Initialize here instead of using late
  String? _qrCodeData;
  Set<int> _pendingCourseIds = {};  // Add this to track pending courses
  bool _contentLoaded = false;
  Set<int> _successCourseIds = {};  // Add this line to track successful payments
  final TextEditingController _verificationController = TextEditingController();
  String _generatedCode = '';

  // Unified animation controllers - remove duplicates
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _headerScaleAnimation; // Added missing declaration
  
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  late Future<void> _refreshFuture;

  // Add these helper methods
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  
  double getAdaptiveSize(double size) {
    return (screenWidth / 375.0) * size * 0.8;
  }

  // Add these properties at the top of the class
  Map<String, dynamic>? _lastViewedVideo;
  late final LocalStorageService _storageService;

  // Add this line with the other state variables
  final bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _selectedCategory = 'My Courses'; // Ensure default tab is My Courses
    _refreshFuture = _loadInitialData();
    _setupScrollListener();
    _initializeStorage(); // Add this line
  }

  // New method to load initial data
  Future<void> _loadInitialData() async {
    if (!_contentLoaded) {
      await Future.wait([
        _loadCourses(),
        _loadPaymentDetails(),
        _loadPendingPayments(),
      ]);
      _contentLoaded = true;
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      }
    });
  }

  void _initializeAnimations() {
    // Primary animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Scale animation controller
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Fade controller
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initialize animations
    _headerScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutExpo,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController, 
      curve: Curves.easeOut
    );
    
    // Start animations
    _animationController.forward();
    _scaleController.forward();
    _fadeController.forward();
  }

Future<void> _loadCourses() async {
  try {
    if (_authService.currentUser == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Please login to view courses';
        });
      }
      return;
    }

    debugPrint('Loading courses...');
    setState(() => _isLoading = true);
    
    final snapshot = await _coursesRef.get().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timeout. Please check your internet.');
      },
    );
    
    if (!snapshot.exists || snapshot.value == null) {
      if (mounted) {
        setState(() {
          _courses = [];
          _isLoading = false;
          _error = null; // Don't show error for empty courses
        });
      }
      return;
    }

    final data = snapshot.value as Map;
    final courses = <Course>[];
    
    data.forEach((key, value) {
      if (value is Map) {
        try {
          final course = Course.fromRTDB(value);
          // Validate required fields
          if (course.name.isNotEmpty && 
              course.image.isNotEmpty && 
              course.duration.isNotEmpty) {
            courses.add(course);
          }
        } catch (e) {
          debugPrint('Error parsing course: $e');
        }
      }
    });

    if (mounted) {
      setState(() {
        _courses = courses;
        _isLoading = false;
        _error = null;
      });
    }
  } on TimeoutException catch (_) {
    _handleError('Connection timeout. Please check your internet.');
  } catch (e) {
    _handleError('Error loading courses: $e');
  }
}

void _handleError(String message) {
  debugPrint(message);
  if (mounted) {
    setState(() {
      _isLoading = false;
      _error = message;
      _courses = [];
    });
  }
}

  Future<void> _loadPaymentDetails() async {
    try {
      final snapshot = await _paymentRef.get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        if (mounted) {
          setState(() {
            _payeeName = data['name']?.toString();
            _upiId = data['upiid']?.toString();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading payment details: $e');
    }
  }

  Future<void> _loadPendingPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final currentUserUid = user.uid; // current user id
      debugPrint('Loading payments for user: $currentUserUid');
      
      // Clear existing sets
      _pendingCourseIds = {};
      _successCourseIds = {};

      final paymentsRef = FirebaseDatabase.instance.ref().child('payments');
      final snapshot = await paymentsRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final payments = snapshot.value as Map;
        
        payments.forEach((paymentId, payment) {
          if (payment is Map) {
            // Filter by userId
            if (payment['userId'] != currentUserUid) return;
            
            final courseId = payment['courseId'];
            final status = payment['status'];
            final id = courseId is int ? courseId : int.tryParse(courseId.toString());
            
            if (id != null) {
              debugPrint('Found payment for user - CourseId: $id, Status: $status');
              
              if (status == 'success') {
                _successCourseIds.add(id);
              } else if (status == 'pending') {
                _pendingCourseIds.add(id);
              }
            }
          }
        });
      }
      debugPrint('Final payment status for user:');
      debugPrint('Success courses: $_successCourseIds');
      debugPrint('Pending courses: $_pendingCourseIds');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading payments: $e');
    }
  }

  String _generateUpiUrl(Course course) {
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
        'am': course.price.toStringAsFixed(2),
        'tn': 'Course: ${course.name}\nUser ID: $userId\nEmail: $userEmail\nTxn: $transactionId',
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

Widget _buildRecentlyViewedSection() {
  if (_isLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());

  try {
    final lastVideo = _storageService.getLastViewedVideo();
    if (lastVideo == null) {
      debugPrint('No last viewed video found');
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final courseId = int.tryParse(lastVideo['courseId']?.toString().replaceAll('c', '') ?? '');
    if (courseId == null) {
      debugPrint('Invalid course ID in stored data');
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Find matching course from available courses
    final course = _courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => Course(
        id: courseId,
        name: 'Unknown Course',
        description: 'Description not available',
        duration: '0:00',
        image: '',
        src: '',
        price: 0,
      ),
    );

    // Only show if course is purchased
    if (!_successCourseIds.contains(courseId)) {
      debugPrint('Course not purchased');
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final progress = (lastVideo['progress'] as num?)?.toDouble() ?? 0.0;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(8), // Reduced padding
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: OpenContainer<bool>(
            transitionType: ContainerTransitionType.fadeThrough,
            openBuilder: (context, _) {
              return VideoPlayerScreen(
                courseId: 'c${course.id}',
                title: course.name,
              );
            },
            closedElevation: 8,
            openElevation: 0,
            closedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            closedColor: Colors.transparent,
            openColor: Colors.transparent,
            closedBuilder: (BuildContext context, VoidCallback openContainer) {
              return Container(
                height: 160, // Increased from 130 to 160
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Hero(
                        tag: 'course_${course.id}_image',
                        child: Image.network(
                          course.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error_outline),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Changed to spaceBetween
                        children: [
                          // Continue Learning badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Continue Learning',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom content
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16, // Reduced size
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1, // Limited to 1 line
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Progress bar and text
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 4, // Reduced height
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(progress * 100).toInt()}% Complete',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11, // Reduced size
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add a pulse animation around play button
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        width: 36, // Reduced size
                        height: 36, // Reduced size
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: AppColors.primary,
                          size: 20, // Reduced size
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error building recently viewed section: $e');
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    try {
      // Get screen dimensions for responsive layout
      final size = MediaQuery.of(context).size;
      final padding = MediaQuery.of(context).padding;
      
      // Calculate responsive values with safety checks
      final isTablet = size.width > 600;
      final gridCount = isTablet ? 3 : 2;
      final headerHeight = size.height * 0.28;
      final cardHeight = size.width * (isTablet ? 0.25 : 0.35);

      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: RefreshIndicator(
          onRefresh: _refreshContent,
          child: _buildMainContent(gridCount, headerHeight, cardHeight, padding),
        ),
      );
    } catch (e) {
      debugPrint('Error building course screen: $e');
      return const Scaffold(
        body: Center(
          child: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

Widget _buildMainContent(int gridCount, double headerHeight, double cardHeight, EdgeInsets padding) {
  // Get current user from Firebase and fetch name from database
  final user = FirebaseAuth.instance.currentUser;
  final userRef = FirebaseDatabase.instance.ref().child('users').child(user?.uid ?? '');
  
  return StreamBuilder(
    stream: userRef.onValue,
    builder: (context, AsyncSnapshot snapshot) {
      String userName = 'Student';
      if (snapshot.hasData && snapshot.data?.snapshot?.value != null) {
        final userData = snapshot.data!.snapshot.value as Map;
        userName = userData['name']?.toString() ?? 'Student';
      }

      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Changed greeting to a single row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Row(
                      children: [
                        const Text(
                          '👋Hello, ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 4), // Reduced spacing from 8 to 4
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: _buildModernCategoryToggle(),
                  ),
                ],
              ),
            ),
          ),

          // Content with error states
          if (_isLoading)
            _buildShimmerGrid(gridCount, cardHeight)
          else if (_error != null)
            _buildErrorSliver()
          else if (_courses.isEmpty)
            _buildEmptySliver()
          else ...[
            // Only show recently viewed if we have courses
            if (!_isLoading) _buildRecentlyViewedSection(),
            
            // Add section title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Text(
                  _selectedCategory == 'My Courses' ? 'My Courses' : 'All Available Courses',
                  style: const TextStyle(
                    fontSize: 22, // Increased from 20
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            
            // Update padding to match recent viewed section
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), // Reduced padding
              sliver: _buildResponsiveCourseGrid(gridCount, cardHeight),
            ),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      );
    }
  );
}

// Add this helper method in the _CourseScreenState class
double _getResponsiveTextSize(double baseSize) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (screenWidth > 600) {
    // For tablets and larger screens (scale up)
    return baseSize * 1.3;
  } else if (screenWidth < 360) {
    // For very small screens (scale down)
    return baseSize * 0.85;
  }
  // For normal sized screens
  return baseSize;
}

Widget _buildResponsiveCourseGrid(int gridCount, double cardHeight) {
  return SliverGrid(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 1.2, // Made even shorter
      mainAxisSpacing: 8, // Increased spacing
      crossAxisSpacing: 8, // Increased spacing
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final course = _getFilteredCourses()[index];
        return _buildMinimalCourseCard(course);
      },
      childCount: _getFilteredCourses().length,
    ),
  );
}

Widget _buildMinimalCourseCard(Course course) {
  final isPending = _pendingCourseIds.contains(course.id);
  final isSuccess = _successCourseIds.contains(course.id);

  return OpenContainer<bool>(
    transitionType: ContainerTransitionType.fadeThrough,
    openBuilder: (context, _) {
      if (isSuccess) {
        return VideoPlayerScreen(
          courseId: 'c${course.id}',
          title: course.name,
        );
      } else if (!isPending) {
        _handleBuyNow(course);
      }
      return const SizedBox();
    },
    closedElevation: 0, // Remove elevation
    openElevation: 0,
    closedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(  
        color: AppColors.secondary.withOpacity(0.3),
        width: 1,
      ),
    ),
    closedColor: Colors.transparent,
    openColor: Colors.transparent,
    middleColor: Colors.transparent,
    tappable: isSuccess || !isPending,
    closedBuilder: (context, openContainer) {
      return Card(
        elevation: 0, // Remove shadow
        margin: EdgeInsets.zero, // Remove margin
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Match the OpenContainer radius
          side: BorderSide(  // Add 1px border
            color: AppColors.secondary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            if (isSuccess) {
              openContainer();
            } else if (!isPending) {
              _handleBuyNow(course);
            } else {
              _showDetailedCourseSheet(course);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(course.image),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // Duration chip
                Positioned(
                  top: 12, // Increased from 4
                  left: 12, // Increased from 4
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(course.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Status badge
                if (isPending)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                // Bottom content
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6), // Added bottom padding
                    constraints: const BoxConstraints(maxHeight: 85), // Increased for better spacing
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 2, bottom: 6), // Added bottom padding
                          child: Text(
                            course.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18, // Increased from 16
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 2), // Added bottom margin
                          padding: const EdgeInsets.symmetric(
                            vertical: 8, // Increased from 6
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSuccess 
                              ? AppColors.secondary.withOpacity(0.5) // More transparent
                              : isPending
                                ? Colors.orange.withOpacity(0.8)
                                : AppColors.secondary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(35),
                            border: isSuccess ? Border.all(
                              color: AppColors.secondary,
                              width: 2,
                            ) : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSuccess) ...[
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Color.fromARGB(255, 255, 255, 255), // Match border color
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Play Now',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 255, 255, 255), // Match border color
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else if (isPending) ...[
                                const Icon(
                                  Icons.pending_outlined,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else
                                Text(
                                  '₹${course.price}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildPurchasedCoursesGrid() {
  final purchasedCourses = _courses.where((course) {
    return _successCourseIds.contains(course.id) || _pendingCourseIds.contains(course.id);
  }).toList();

  if (purchasedCourses.isEmpty) {
    return SliverToBoxAdapter(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.school_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No courses purchased yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check the All tab to browse available courses',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 8), // Reduced from 16 to 8
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildPurchasedCourseCard(purchasedCourses[index]), // Changed this line
        childCount: purchasedCourses.length,
      ),
    ),
  );
}

// Add this helper function for duration formatting
String _formatDuration(String duration) {
  // Convert durations like "2 weeks" to "2w", "2 days" to "2d", etc.
  final parts = duration.toLowerCase().split(' ');
  if (parts.length != 2) return duration;

  final value = parts[0];
  final unit = parts[1];

  switch (unit) {
    case 'weeks':
    case 'week':
      return '${value}w';
    case 'days':
    case 'day':
      return '${value}d';
    case 'months':
    case 'month':
      return '${value}m';
    case 'years':
    case 'year':
      return '${value}y';
    default:
      return duration;
  }
}

// Update the purchased course card widget
Widget _buildPurchasedCourseCard(Course course) {
  final isPending = _pendingCourseIds.contains(course.id);
  final isSuccess = _successCourseIds.contains(course.id);

  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    child: InkWell(
      onTap: () => _navigateToVideo(course), // Direct video navigation on tap
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              // Course Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  course.image,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // Duration chip
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(course.duration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Status indicator
              if (isPending || isSuccess)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPending ? Colors.orange : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPending ? Icons.pending : Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.3,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isPending ? Colors.orange : Colors.green,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Continue Learning',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (isSuccess)
                      Container(
                        padding: const EdgeInsets.all(12), // Increased from 6
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32, // Increased from 16
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Add this method to show course details
void _showCourseDetails(Course course) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      // Add bottom sheet content here
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Course details content
          // Add your course details UI here
        ],
      ),
    ),
  );
}

Widget _buildAnimatedCourseItem(Course course) {
  final isPending = _pendingCourseIds.contains(course.id);
  final isSuccess = _successCourseIds.contains(course.id);

  return OpenContainer(
    transitionType: ContainerTransitionType.fade,
    openBuilder: (context, _) {
      if (isSuccess) {
        return VideoPlayerScreen(
          courseId: 'c${course.id}',
          title: course.name,
        );
      }
      return const SizedBox();
    },
    closedElevation: 0,
    openElevation: 0,
    closedShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    ),
    closedColor: Colors.transparent,
    openColor: Colors.transparent,
    middleColor: Colors.transparent,
    closedBuilder: (context, openContainer) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              if (isSuccess) {
                openContainer();
              } else if (!isPending) {
                _handleBuyNow(course);
              }
            },
            child: Stack(
              children: [
                // Course Image with Gradient Overlay
                Positioned.fill(
                  child: Hero(
                    tag: 'course_${course.id}_image',
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(course.image),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content Overlay
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(isPending, isSuccess),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPending || isSuccess)
                                  Icon(
                                    isPending ? Icons.pending : Icons.check_circle,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                else ...[
                                  const Icon(
                                    Icons.currency_rupee,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${course.price}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  course.duration,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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

IconData _getStatusIcon(bool isPending, bool isSuccess) {
  if (isPending) return Icons.pending;
  if (isSuccess) return Icons.check_circle;
  return Icons.currency_rupee;
}

// Update color method to use secondary color
Color _getStatusColor(bool isPending, bool isSuccess) {
  if (isPending) return Colors.orange;
  if (isSuccess) return Colors.green;
  return AppColors.secondary; // Changed from primary to secondary
}

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshFuture = _refreshContent();
    });
    await _refreshFuture;
  }

List<Course> _getFilteredCourses() {
  try {
    if (_courses.isEmpty) {
      debugPrint('No courses available'); // Add debug print
      return [];
    }

    List<Course> filteredCourses;
    if (_selectedCategory == 'My Courses') {
      filteredCourses = _courses.where((course) {
        final isSuccess = _successCourseIds.contains(course.id);
        final isPending = _pendingCourseIds.contains(course.id);
        return (isSuccess || isPending);
      }).toList();
    } else {
      filteredCourses = _courses.where((course) {
        return !_successCourseIds.contains(course.id) && 
               !_pendingCourseIds.contains(course.id);
      }).toList();
    }

    // Add debug prints
    debugPrint('Selected category: $_selectedCategory');
    debugPrint('Filtered courses count: ${filteredCourses.length}');
    debugPrint('Success course IDs: $_successCourseIds');
    debugPrint('Pending course IDs: $_pendingCourseIds');

    return filteredCourses;
  } catch (e) {
    debugPrint('Error filtering courses: $e');
    return [];
  }
}

  Widget _buildActionButton(Course course, bool isPending, bool isSuccess) {
    return ElevatedButton(
      onPressed: isPending 
          ? null 
          : isSuccess 
              ? () => _navigateToVideo(course)
              : () => _handleBuyNow(course),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPending 
            ? Colors.orange 
            : isSuccess 
                ? Colors.green
                : AppColors.secondary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        isPending 
            ? 'Pending'
            : isSuccess 
                ? 'View Course'
                : 'Buy Now',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
        color: _remainingSeconds < 60 ? AppColors.secondary.withOpacity(0.1) : Colors.grey[100],
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

  void _handleBuyNow(Course course) {
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
                            // Course details - smaller text
                            Text(
                              course.name,
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
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '₹${course.price}',
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
                                    color: Colors.black.withOpacity(0.05),
                                    spreadRadius: 1,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: _generateUpiUrl(course),
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
                                    ? AppColors.secondary.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isVerificationWrong
                                      ? AppColors.secondary
                                      : AppColors.primary.withOpacity(0.2),
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
                                    course, 
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

                                    // Refresh courses and switch to My Courses tab
                                    setState(() {
                                      _selectedCategory = 'My Courses';
                                    });
                                    await _refreshCourses();
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

Future<void> _submitPayment(Course course, String email) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');

  try {
    debugPrint('Submitting payment for course ${course.id}');
    final paymentRef = FirebaseDatabase.instance.ref().child('payments').push();
    final paymentId = paymentRef.key ?? '';
    
    // Get current timestamp and format date
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final transactionDate = now.toIso8601String();

    final paymentData = {
      'amount': course.price,
      'courseId': course.id,
      'courseName': course.name,
      'email': email,
      'paymentId': paymentId,
      'paymentMethod': 'UPI',
      'status': 'pending', // Set default status as pending
      'timestamp': timestamp,
      'transactionDate': transactionDate,
      'userEmail': user.email,
      'userId': user.uid,
    };

    await paymentRef.set(paymentData);
    
    // Update local state to show pending status
    setState(() {
      _pendingCourseIds.add(course.id);
      _selectedCategory = 'My Courses';
    });

    // Reload payments to refresh UI
    await _loadPendingPayments();
    
  } catch (e) {
    debugPrint('Payment submission error: $e');
    throw Exception('Failed to submit payment: $e');
  }
}

  @override
  void dispose() {
    _paymentTimer?.cancel();
    _emailController.dispose();
    _animationController.dispose();
    _scaleController.dispose();
    _scrollController.dispose();
    _verificationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;  // Add this getter

  // Add this method to navigate to video player
  void _navigateToVideo(Course course) async {
    if (!mounted) return;

    try {
      final isPurchased = _successCourseIds.contains(course.id);
      
      if (!isPurchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please purchase this course to access content')),
        );
        return;
      }

      final courseId = 'c${course.id}';

      // Save to local storage first
      await _storageService.savePurchasedCourse(courseId);

      if (!mounted) return;

      // Navigate with saved purchase status
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            courseId: courseId,
            title: course.name,
          ),
        ),
      );

      // Refresh the course list after returning
      await _refreshContent();
      
    } catch (e) {
      debugPrint('Error navigating to video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error accessing course content')),
        );
      }
    }
  }

  Future<void> _refreshCourses() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await Future.wait([
        _loadCourses(),
        _loadPaymentDetails(),
        _loadPendingPayments(),
      ]);
    } catch (e) {
      debugPrint('Error refreshing courses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshContent() async {
    await Future.wait([
      _loadCourses(),
      _loadPaymentDetails(),
      _loadPendingPayments(),
    ]);
  }

  Widget _buildErrorSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourses,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildEmptySliver() {
  // If we're showing "All" courses
  if (_selectedCategory == 'All') {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: AppColors.secondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Courses Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New courses will be added soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  } 
  
  // If we're showing "My Courses"
  return SliverFillRemaining(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_books_outlined,
            size: 64,
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Courses Purchased',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch to "All" tab to browse available courses',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

  // Add this method
  Future<void> _initializeStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = LocalStorageService(prefs);
    if (mounted) {
      setState(() {
        _lastViewedVideo = _storageService.getLastViewedVideo();
      });
    }
  }

  Widget _buildAnimatedPurchasedCourseCard(Course course) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: OpenContainer<bool>(
          transitionType: ContainerTransitionType.fadeThrough,
          openBuilder: (BuildContext context, VoidCallback _) {
            if (_successCourseIds.contains(course.id)) {
              return VideoPlayerScreen(courseId: 'c${course.id}', title: course.name);
            }
            return const SizedBox(); // Fallback empty widget
          },
          closedElevation: 0,
          openElevation: 0,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          closedColor: Colors.transparent,
          openColor: Colors.transparent,
          middleColor: Colors.transparent,
          tappable: _successCourseIds.contains(course.id),
          closedBuilder: (BuildContext context, VoidCallback openContainer) {
            return _buildPurchasedCourseCard(course); // Replace AnimatedContainer with existing card builder
          },
        ),
      ),
    );
  }

  Widget _buildModernCategoryToggle() {
    return GestureDetector(
      // Listen to horizontal swipes
      onHorizontalDragEnd: (details) {
        HapticFeedback.selectionClick();
        // If swipe left or right, toggle between the two categories
        if (_categories.length > 1) {
          int currentIndex = _categories.indexOf(_selectedCategory);
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            // Swipe Left: go to next tab; if at end, go back to start
            int nextIndex = (currentIndex + 1) % _categories.length;
            setState(() => _selectedCategory = _categories[nextIndex]);
          } else if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            // Swipe Right: go to previous tab; if at beginning, go to last
            int prevIndex = (currentIndex - 1 + _categories.length) % _categories.length;
            setState(() => _selectedCategory = _categories[prevIndex]);
          }
        }
      },
      child: Container(
        height: 40, // Increased height from 36 to 40
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            // Calculate enrolled courses count for "My Courses" tab
            final enrolledCount = category == 'My Courses' 
                ? _successCourseIds.length + _pendingCourseIds.length 
                : null;
            
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedCategory = category;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondary : Colors.transparent, // use secondary color
                    borderRadius: BorderRadius.circular(20), // More rounded
                    border: Border.all(
                      color: AppColors.secondary,
                      width: 1, // Added 1px border in secondary color
                    ),
                  ),
                  child: Center(
                    child: Text(
                      // Add enrolled count to My Courses tab text
                      category == 'My Courses' && enrolledCount! > 0
                          ? 'My Courses ($enrolledCount)'
                          : category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Move this method inside the class, near other UI-related methods
  void _showDetailedCourseSheet(Course course) {
    final isPending = _pendingCourseIds.contains(course.id);
    final isSuccess = _successCourseIds.contains(course.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Course image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                course.image,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course name
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Status chips row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(isPending, isSuccess),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(isPending, isSuccess),
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPending ? 'Pending' : 'Enrolled',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDurationChip(course.duration),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    const Text(
                      'About this course',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action button
                    if (isSuccess) ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToVideo(course);
                      },
                      icon: const Icon(Icons.play_circle_outlined),
                      label: const Text('Continue Learning'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
  }
}

// Add CurvedProgressPainter class at the bottom of the file
class CurvedProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  CurvedProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - paint.strokeWidth / 2;

    // Draw background circle
    canvas.drawCircle(center, radius, paint);

    // Draw progress arc
    paint.color = color;
    final progressRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      progressRect,
      -pi / 2, // Start from top
      2 * pi * progress, // Draw based on progress
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CurvedProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

  Widget _buildDurationChip(String duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            duration,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

class _CustomHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double maxHeight;
  final double minHeight;
  final Widget child;

  _CustomHeaderDelegate({
    required this.maxHeight,
    required this.minHeight,
    required this.child,
  });

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    final progress = shrinkOffset / (maxHeight - minHeight);
    
    return Opacity(
      opacity: 1 - progress,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CustomHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
           minHeight != oldDelegate.minHeight ||
           child != oldDelegate.child;
  }
}

// Add this method for shimmer loading grid
Widget _buildShimmerGrid(int gridCount, double cardHeight) {
  return SliverGrid(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: gridCount,
      childAspectRatio: 0.75,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) => ShimmerLoading(
        baseColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childCount: 6,
    ),
  );
}

// Add this method for icon buttons
Widget _buildIconButton({
  required IconData icon,
  required VoidCallback onTap,
  Color? iconColor,
  Color? backgroundColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: backgroundColor ?? Colors.white.withOpacity(0.2),
      shape: BoxShape.circle,
      boxShadow: backgroundColor != null ? [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ] : null,
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: 24,
          ),
        ),
      ),
    ),
  );
}

// Add thecondary color is extension method at the bottom of the file
extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;
    try {
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    } catch (e) {
      debugPrint('Error capitalizing string: $e');
      return this; // Return original string if operation fails
    }
  }
}