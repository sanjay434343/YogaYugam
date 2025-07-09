import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:yoga/screens/video_player_screen.dart';
import 'dart:async';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/shimmer_loading.dart';
import 'dart:math';

class Course {
  final int id;
  final String name;
  final String description;
  final String duration;
  final String image;
  final String src;
  final int price;
  final String category;
  final double progress;
  final List<Lesson> lessons;
  final String title;

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.image,
    required this.src,
    required this.price,
    this.category = 'All',
    this.progress = 0.0,
    this.lessons = const [],
    String? title,
  }) : title = title ?? name;

  factory Course.fromRTDB(Map<dynamic, dynamic> map) {
    int parseId() {
      var rawId = map['id'];
      if (rawId is int) return rawId;
      if (rawId is String) return int.tryParse(rawId) ?? 0;
      return 0;
    }

    int parsePrice() {
      var rawPrice = map['price'];
      if (rawPrice is int) return rawPrice;
      if (rawPrice is String) return int.tryParse(rawPrice) ?? 0;
      if (rawPrice is double) return rawPrice.toInt();
      return 0;
    }

    return Course(
      id: parseId(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      duration: map['duration']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      src: map['src']?.toString() ?? '',
      price: parsePrice(),
      category: map['category']?.toString() ?? 'All',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  void startCourse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          courseId: 'c$id',  // Convert id to String with 'c' prefix
          title: title,
        ),
      ),
    );
  }
}

class Lesson {
  final String id;
  final String title;
  
  Lesson({required this.id, required this.title});
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
  late Animation<double> _fadeAnimation;
  final List<String> _categories = ['My Courses', 'All'];
  String _selectedCategory = 'My Courses';
  final DatabaseReference _paymentRef = FirebaseDatabase.instance.ref().child('payment');
  String? _payeeName;
  String? _upiId;
  final TextEditingController _emailController = TextEditingController();
  Timer? _paymentTimer;
  int _remainingSeconds = 300;
  final bool _showPendingState = false;
  String? _qrCodeData;
  Set<int> _pendingCourseIds = {};
  bool _contentLoaded = false;
  Set<int> _successCourseIds = {};
  final TextEditingController _verificationController = TextEditingController();
  String _generatedCode = '';

  late AnimationController _scaleController;
  late Animation<double> _headerScaleAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  late Future<void> _refreshFuture;

  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;

  double getAdaptiveSize(double size) {
    return (screenWidth / 375.0) * size * 0.8;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _refreshFuture = _loadInitialData();
    _setupScrollListener();
  }

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
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _headerScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutExpo,
    ));

    _cardScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutExpo,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutExpo,
    ));

    _animationController.forward();
    _scaleController.forward();
  }

  Future<void> _loadCourses() async {
    if (_authService.currentUser == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please login to view courses';
      });
      return;
    }

    try {
      debugPrint('Loading courses...');
      final snapshot = await _coursesRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          _courses = [];
          _isLoading = false;
          _error = 'No courses found';
        });
        return;
      }

      final data = snapshot.value as Map;
      final courses = <Course>[];

      data.forEach((key, value) {
        if (value is Map) {
          try {
            courses.add(Course.fromRTDB(value));
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
    } catch (e) {
      debugPrint('Error loading courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error: ${e.toString()}';
        });
      }
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

  Future<void> _loadPendingPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final paymentsRef = FirebaseDatabase.instance.ref().child('payments');

      try {
        final query = paymentsRef.orderByChild('userId').equalTo(user.uid);
        final snapshot = await query.get();
        if (snapshot.exists && snapshot.value != null) {
          final payments = snapshot.value as Map;
          final pendingIds = payments.values
              .where((payment) => payment['status'] == 'pending')
              .map((payment) => payment['courseId'] as int)
              .toSet();

          final successIds = payments.values
              .where((payment) => payment['status'] == 'success')
              .map((payment) => payment['courseId'] as int)
              .toSet();

          setState(() {
            _pendingCourseIds = pendingIds;
            _successCourseIds = successIds;
          });
        }
      } catch (e) {
        final snapshot = await paymentsRef.get();
        if (snapshot.exists && snapshot.value != null) {
          final allPayments = snapshot.value as Map;
          final pendingIds = allPayments.values
              .where((payment) =>
                  payment['userId'] == user.uid &&
                  payment['status'] == 'pending')
              .map((payment) => payment['courseId'] as int)
              .toSet();

          final successIds = allPayments.values
              .where((payment) =>
                  payment['userId'] == user.uid &&
                  payment['status'] == 'success')
              .map((payment) => payment['courseId'] as int)
              .toSet();

          setState(() {
            _pendingCourseIds = pendingIds;
            _successCourseIds = successIds;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pending payments: $e');
    }
  }

  String _generateUpiUrl(Course course) {
    if (_upiId == null || _payeeName == null) {
      return 'Error: Payment details not available';
    }

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

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => ShimmerLoading(
        baseColor: AppColors.primary.withOpacity(0.1),
        highlightColor: AppColors.primary.withOpacity(0.05),
        child: const CourseShimmerCard(),
      ),
    );
  }

  Widget _buildLoadingHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(
            child: Container(
              height: 32,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: ShimmerLoading(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalPurchased = _pendingCourseIds.length + _successCourseIds.length;
    final headerOpacity = (1 - (_scrollOffset / 100)).clamp(0.0, 1.0);

    return ScaleTransition(
      scale: _headerScaleAnimation,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          24 - (_scrollOffset * 0.1).clamp(0, 16),
          16,
          16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05 * headerOpacity),
              AppColors.primary.withOpacity(0.02 * headerOpacity),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi ${FirebaseAuth.instance.currentUser?.displayName?.split(' ')[0] ?? 'there'}! 👋',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Text(
                        'Start Your Journey',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totalPurchased > 0)
                  Badge(
                    label: Text(totalPurchased.toString()),
                    child: IconButton(
                      icon: Icon(
                        Icons.library_books,
                        color: _selectedCategory == 'My Courses'
                            ? AppColors.secondary 
                            : Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _selectedCategory = 'My Courses'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    'My Courses',
                    Icons.person,
                    _pendingCourseIds.length,
                  ),
                  const SizedBox(width: 12),
                  _buildCategoryChip('All', Icons.grid_view_rounded, 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, IconData icon, int badgeCount) {
    final isSelected = _selectedCategory == category;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.secondary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selectedCategory = category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _scrollOffset > 50
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            _isLoading ? _buildLoadingHeader() : _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                displacement: 100,
                strokeWidth: 3,
                color: AppColors.primary,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: _isLoading
                          ? _buildLoadingList()
                          : _error != null
                              ? _buildErrorSliver()
                              : _courses.isEmpty
                                  ? _buildEmptySliver()
                                  : _buildCoursesList(),
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

  Future<void> _handleRefresh() async {
    setState(() {
      _refreshFuture = _refreshContent();
    });
    await _refreshFuture;
  }

  List<Course> _getFilteredCourses() {
    if (_selectedCategory == 'My Courses') {
      return _courses.where((course) =>
        _pendingCourseIds.contains(course.id) ||
        _successCourseIds.contains(course.id)
      ).toList();
    } else {
      return _courses.where((course) =>
        !_pendingCourseIds.contains(course.id) &&
        !_successCourseIds.contains(course.id)
      ).toList();
    }
  }

  Widget _buildCoursesList() {
    final filteredCourses = _getFilteredCourses();
    final bool showingMyCourses = _selectedCategory == 'My Courses';

    if (showingMyCourses && filteredCourses.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_books_outlined,
                size: 64,
                color: AppColors.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No purchased courses yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _selectedCategory = 'All'),
                child: const Text('Browse all courses'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildCourseCard(filteredCourses[index], index),
        childCount: filteredCourses.length,
      ),
    );
  }

  Widget _buildCourseCard(Course course, int index) {
    final isPending = _pendingCourseIds.contains(course.id);
    final isSuccess = _successCourseIds.contains(course.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: _scaleController,
                curve: Interval(
                  (index * 0.1).clamp(0.0, 1.0),
                  ((index + 1) * 0.1).clamp(0.0, 1.0),
                  curve: Curves.easeOutExpo,
                ),
              )).value,
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (isSuccess) {
                  _navigateToVideo(course);
                } else if (!isPending) {
                  _handleBuyNow(course);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'course_${course.id}_image',
                          child: Image.network(
                            course.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error_outline),
                                ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
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
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _buildStatusBadge(isPending, isSuccess),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _buildDurationChip(course.duration),
                        ),
                      ],
                    ),
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
                        Text(
                          course.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              '₹${course.price}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            _buildActionButton(course, isPending, isSuccess),
                          ],
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
  }

  Widget _buildStatusBadge(bool isPending, bool isSuccess) {
    if (!isPending && !isSuccess) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange : Colors.green,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPending ? Icons.pending_outlined : Icons.check_circle_outline,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isPending ? 'PENDING' : 'PURCHASED',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String duration) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
    _remainingSeconds = 300;

    _paymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        if (context.mounted) {
          Navigator.pop(context);
        }
        return;
      }

      if (context.mounted) {
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
        color: _remainingSeconds < 60 ? Colors.red.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
            size: 18,
            color: _remainingSeconds < 60 ? Colors.red : Colors.grey[600],
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_remainingSeconds),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _remainingSeconds < 60 ? Colors.red : Colors.grey[800],
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
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              course.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
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
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
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
                                    size: 180.0,
                                    backgroundColor: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.qr_code_scanner,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Scan with UPI App',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
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
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isVerificationWrong
                                    ? Colors.red.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isVerificationWrong
                                      ? Colors.red
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
                                          ? Colors.red
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
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (_verificationController.text != _generatedCode) {
                                  setModalState(() {
                                    isVerificationWrong = true;
                                  });
                                  return;
                                }

                                try {
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
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

                                  await _submitPayment(
                                    course,
                                    FirebaseAuth.instance.currentUser?.email ?? '',
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payment submitted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No courses available',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new courses',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.5),
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
    );
  }

  Future<void> _savePaymentDetails(Course course, String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final paymentRef = FirebaseDatabase.instance.ref().child('payments').push();
    await paymentRef.set({
      'userId': user.uid,
      'userEmail': user.email,
      'courseId': course.id,
      'courseName': course.name,
      'amount': course.price,
      'email': email,
      'timestamp': ServerValue.timestamp,
      'status': 'pending',
      'paymentId': paymentRef.key,
    });
  }

  Future<void> _submitPayment(Course course, String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final paymentRef = FirebaseDatabase.instance.ref().child('payments').push();
      await paymentRef.set({
        'userId': user.uid,
        'userEmail': user.email,
        'courseId': course.id,
        'courseName': course.name,
        'amount': course.price,
        'email': email,
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
        'paymentId': paymentRef.key,
        'paymentMethod': 'UPI',
        'transactionDate': DateTime.now().toIso8601String(),
      });

      setState(() {
        _pendingCourseIds.add(course.id);
        _selectedCategory = 'My Courses';
      });

    } catch (e) {
      debugPrint('Payment submission error: $e');
      throw Exception('Failed to submit payment. Please try again.');
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
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _navigateToVideo(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          courseId: 'c${course.id}',
          title: course.name,
        ),
      ),
    );
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

  Widget _buildLoadingList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ShimmerLoading(
            baseColor: AppColors.primary.withOpacity(0.1),
            highlightColor: AppColors.primary.withOpacity(0.05),
            child: const CourseShimmerCard(),
          ),
        ),
        childCount: 3,
      ),
    );
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
              color: Colors.red.withOpacity(0.5),
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
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No courses available',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new courses',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

    canvas.drawCircle(center, radius, paint);

    paint.color = color;
    final progressRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      progressRect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CurvedProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}