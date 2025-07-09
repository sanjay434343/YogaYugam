import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'course_screen.dart';  // Add this import
import '../theme/colors.dart';  // Add this import
import 'profile_screen.dart';  // Add this import
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../widgets/notification_drawer.dart';
import '../services/notification_service.dart' as service;  // Add alias
import 'training_page.dart';  // Add this import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// Add this import
// Add this import
import '../painters/profile_pattern_painter.dart'; // Add this import
import '../services/payment_service.dart';
import 'dart:async'; // Add this import for StreamSubscription
// Add this import
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
// Add this import
import '../widgets/shimmer_loading.dart';  // Add this import with other imports
// Add this import
import 'poll_screen.dart';
import 'dart:math'; // Add this import
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import '../services/local_storage_service.dart'; // Add this import
// Add this import
import 'package:gauge_chart/gauge_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final authService = AuthService();
  final databaseService = DatabaseService();
  final service.NotificationService notificationService = service.NotificationService();
  final List<service.NotificationItem> notifications = [];
  int selectedIndex = 0;
  Map<String, dynamic>? userData0;

  late final AnimationController animationController;
  late final Animation<double> fadeAnimation;
  late final Animation<Offset> slideAnimation;
  late Animation<double> progressAnimation;

  late FirebaseMessaging messaging;

  // Add this line
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  // Add these animations
  final List<AnimationController> cardControllers = [];
  final List<Animation<double>> cardScales = [];
  final List<Animation<double>> cardOpacities = [];

  final auth = FirebaseAuth.instance;
  final database = FirebaseDatabase.instance.ref();
  String? userName;
  int totalPoints = 0;

  // Add these new animation controllers
  late AnimationController quoteController;
  late AnimationController cardScaleController;
  late Animation<double> cardScale;
  final List<Animation<double>> characterOpacities = [];

  // Add these properties
  Map<String, dynamic> weeklyActivities = {};
  Map<String, dynamic> monthlyActivities = {};
  String weeklyProgress = '0/7';
  String monthlyProgress = '0/30';
  Map<String, dynamic>? pollData;

  // Add this variable for tracking selected option
  String? selectedPollOption;

  // Add this key
  final PageStorageBucket _bucket = PageStorageBucket();

  // Add this controller
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> purchasedCourses = []; // Add this line

  // Add these state variables
  bool _isLoading = false;
  final List<Map<String, dynamic>> _courses = [];
  final Set<String> _pendingCourseIds = {};
  final Set<String> _successCourseIds = {};

  // Add these properties
  bool _hasNewPoll = false;
  DateTime? _lastPollCheck;

  // Add these sizing helpers
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  
  // Helper method for adaptive sizing
  double getAdaptiveSize(double size) {
    // Make everything 20% smaller
    return (screenWidth / 375.0) * size * 0.8;
  }

  // Helper for text sizes
  double getAdaptiveTextSize(double size) {
    double scaleFactor = screenWidth / 375.0;
    // Make text slightly larger (0.9 instead of 0.8)
    return size * scaleFactor.clamp(0.7, 1.1) * 0.9;
  }

  final PaymentService _paymentService = PaymentService();
  int _purchasedCoursesCount = 0;

  StreamSubscription<DatabaseEvent>? _profileSubscription;
  StreamSubscription<DatabaseEvent>? _activitiesSubscription;

  // Add these properties at the top of the _HomeScreenState class
  List<Map<String, dynamic>> _featuredPractices = [];
  bool _isLoadingPractices = true;

  late final HomeController _controller;

  // Add this property with other animation controllers
  late final AnimationController progressController;

  // Add this property to store progress card animation controllers
  final Map<String, AnimationController> _progressCardControllers = {};

  // Add these properties
  Map<String, dynamic> _pointsHistory = {};
  Map<String, int> _dailyPoints = {};
  bool _isLoadingProgress = true;

  // Add these properties
  late final LocalStorageService _storageService;
  Map<String, dynamic>? _lastViewedVideo;

  // Add this property
  int _purchasedPracticesCount = 0;

  // Add a new field for today's progress
  int _todayProgress = 0;
  int _todayGoal = 100; // Default goal is 100%

  @override
  void initState() {
    super.initState();
    
    // Add this debug line with broadcast stream
    final profileStream = database
        .child('profile/${auth.currentUser?.uid}')
        .onValue
        .asBroadcastStream();

    profileStream.listen((event) {
      debugPrint('Profile data: ${event.snapshot.value}');
    }, onError: (error) {
      debugPrint('Error loading profile: $error');
    });

    // Move animation initialization before other initializations
    initializeGreetingCardAnimations();
    
    // Rest of your existing initState calls
    initializeServices();
    // Add this to set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary, // Color for Android
        statusBarIconBrightness: Brightness.light, // Dark icons for Android
        statusBarBrightness: Brightness.dark, // Light icons for iOS
      ),
    );
    initializeAnimations();
    initializeData();
    initializeNotifications();
    notificationService.initializeFCM();
    initializeCardAnimations();
    loadUserData();
    loadUserProfile();
    loadActivityData();
    loadPurchasedCourses(); // Add this line
    checkForNewPoll();
    _loadPurchasedCoursesCount();
    _loadPurchasedPracticesCount(); // Add this line
    _loadFeaturedPractices(); // Add this line
    _calculateTodayProgress(); // Add this to calculate today's progress

    _profileSubscription = database
        .child('profile/${auth.currentUser?.uid}')
        .onValue
        .listen((event) {
      debugPrint('Profile data: ${event.snapshot.value}');
      if (mounted) {
        setState(() {
          userData0 = event.snapshot.value as Map<String, dynamic>?;
        });
      }
    }, onError: (error) {
      debugPrint('Error loading profile: $error');
    });

    _activitiesSubscription = database
        .child('users/${auth.currentUser?.uid}/userdata/activities')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.value != null) {
        final activitiesMap = Map<String, dynamic>.from(event.snapshot.value as Map);
        final activities = convertActivitiesData(activitiesMap);
        
        // Process weekly data
        final weeklyData = processActivities(
          activities,
          DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
          const Duration(days: 7),
        );

        // Process monthly data
        final monthlyData = processActivities(
          activities,
          DateTime(DateTime.now().year, DateTime.now().month, 1),
          const Duration(days: 30),
        );

        setState(() {
          weeklyActivities = weeklyData;
          monthlyActivities = monthlyData;
          weeklyProgress = '${weeklyData.length}/7';
          monthlyProgress = '${monthlyData.length}/${DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day}';
        });
      }
    }, onError: (error) {
      debugPrint('Error loading activities: $error');
    });

    _controller = HomeController();
    _loadData();

    // Add this initialization with other animation initializations
    progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    progressAnimation = CurvedAnimation(
      parent: progressController,
      curve: Curves.easeOutBack,
    );

    _loadPointsHistory();
    _initializeStorage(); // Add this line

    // Add a listener to update points in real-time
    database
      .child('users/${auth.currentUser?.uid}/userdata/totalpoints')
      .onValue
      .listen((event) {
        if (mounted && event.snapshot.exists && event.snapshot.value != null) {
          setState(() {
            totalPoints = (event.snapshot.value as int?) ?? 0;
            _calculateTodayProgress(); // Recalculate progress when points change
          });
        }
      }, onError: (error) {
        debugPrint('Error listening to points update: $error');
      });

    // Add this new stream subscription for points
    database
        .child('users/${auth.currentUser?.uid}/userdata/totalpoints')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.exists) {
        setState(() {
          totalPoints = (event.snapshot.value as int?) ?? 0;
          _calculateTodayProgress(); // Update progress when points change
        });
      }
    }, onError: (error) {
      debugPrint('Error listening to total points: $error');
    });

    // Add this stream for daily points
    database
        .child('users/${auth.currentUser?.uid}/points_history')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.exists && event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _processDailyPoints(data);
      }
    }, onError: (error) {
      debugPrint('Error listening to points history: $error');
    });

    // Add this listener for real-time progress updates
    _setupProgressListeners();

    // Update the points listener to handle real-time updates better
    database
        .child('users/${auth.currentUser?.uid}')
        .onValue
        .listen((event) {
      if (mounted && event.snapshot.exists && event.snapshot.value != null) {
        final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        final points = userData['userdata']?['totalpoints'] ?? 0;
        final today = DateTime.now().toIso8601String().split('T')[0];
        final todayKey = '${today}T00:00:00.000';
        
        setState(() {
          totalPoints = points;
          // Update daily points immediately
          _dailyPoints[todayKey] = points;
          // Recalculate progress
          _calculateTodayProgress();
          weeklyProgress = _calculateWeeklyProgress();
          monthlyProgress = _calculateMonthlyProgress();
          
          // Trigger animations
          progressController.forward(from: 0.0);
          _progressCardControllers.values.forEach((controller) {
            controller.forward(from: 0.0);
          });
        });
      }
    }, onError: (error) {
      debugPrint('Error listening to user data: $error');
    });
  }

  @override
  void didChangeDependencies() {
  }

  Future<void> initializeServices() async {
    try {
      await notificationService.init();
      print("Notification service initialized");
      
      // Test database connection
      await notificationService.testDatabaseConnection();
      
      notificationService.getNotifications().listen(
        (notifications) {
          print("Received ${notifications.length} notifications");
          for (var n in notifications) {
            print("Notification: ${n.title}");
          }
        },
        onError: (error) {
          print("Error listening to notifications: $error");
        },
      );
    } catch (e) {
      print("Error initializing services: $e");
    }
  }

  Future<void> loadNotifications() async {
    // Here you would typically load notifications from your backend
    // For now, we'll add some dummy data
    setState(() {
      notifications.addAll([
        service.NotificationItem(
          id: '1',
          title: 'Welcome to Yogam',
          content: 'Start your yoga journey today!',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: false,
        ),
      ]);
    });
  }

  void initializeAnimations() {
    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
    );

    progressAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutBack,
    );
    
    // Start the animation
    animationController.forward();
  }

  Future<void> initializeData() async {
    final user = authService.currentUser;
    if (user != null) {
      await databaseService.initializeUserIfNeeded(user);
      databaseService.getUserData(user.uid).listen(
        (data) {
          if (mounted) {
            setState(() => userData0 = data);
          }
        },
        onError: (error) => debugPrint('Stream error: $error'),
      );
    }
  }

  void initializeNotifications() {
    messaging = FirebaseMessaging.instance;
    messaging.requestPermission();
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        setState(() {
          notifications.insert(
            0,
            service.NotificationItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: message.notification?.title ?? 'New Notification',
              content: message.notification?.body ?? '',
              timestamp: DateTime.now(),
              isRead: false,
            ),
          );
        });
      }
    });

    // Get existing notifications
    loadNotifications();
  }

  void initializeCardAnimations() {
    // Create animations for each card
    for (int i = 0; i < 2; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      
      cardControllers.add(controller);
      
      cardScales.add(
        CurvedAnimation(
          parent: controller,
          curve: Interval(
            0.2 * i,
            0.6 + (0.2 * i),
            curve: Curves.easeOutBack,
          ),
        ),
      );
      
      cardOpacities.add(
        CurvedAnimation(
          parent: controller,
          curve: Interval(
            0.1 * i,
            0.5 + (0.1 * i),
            curve: Curves.easeOut,
          ),
        ),
      );
      
      // Start the animation with a slight delay for each card
      Future.delayed(Duration(milliseconds: 100 * i), () {
        controller.forward();
      });
    }
  }

  // Add this new method
  void initializeGreetingCardAnimations() {
    quoteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    cardScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    cardScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: cardScaleController,
      curve: Curves.easeOutBack,
    ));

    // Initialize character animations
    const quote = "Yoga is the practice of grounding the body, calming the mind, and awakening the soul every single day.";
    for (int i = 0; i < quote.length; i++) {
      characterOpacities.add(
        Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: quoteController,
            curve: Interval(
              (i / quote.length) * 0.5,
              (i / quote.length) * 0.5 + 0.5,
              curve: Curves.easeOut,
            ),
          ),
        ),
      );
    }

    // Start animations
    cardScaleController.forward();
    quoteController.forward();
  }

  // Fix the _onItemTapped method
  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void navigateToSection(int index) {
    setState(() {
      selectedIndex = index;
    });
    // Here you can add navigation logic for different sections
    switch (index) {
      case 1:
        // Handle video library navigation
        break;
      // Add more cases as needed
    }
  }

  // Update the _openNotifications method
  void openNotifications() {
    setState(() {
      _lastPollCheck = DateTime.now();
      _hasNewPoll = false;
    });
    scaffoldKey.currentState?.openEndDrawer();
  }

  // Update the notification button to show red dot only for unread notifications
  Widget buildNotificationButton() {
    return StreamBuilder<List<service.NotificationItem>>(
      stream: notificationService.getNotifications(),
      builder: (context, snapshot) {
        final hasUnread = snapshot.data?.any((n) => !n.isRead) ?? false;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => scaffoldKey.currentState?.openEndDrawer(),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3), // Increased opacity
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white, // Changed to white
                    size: 22, // Slightly larger
                  ),
                  if (hasUnread || _hasNewPoll)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _hasNewPoll ? Colors.red : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1,
                          ),
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

  Widget buildHomeTab() {
    final user = authService.currentUser;
    if (user == null) return const SizedBox();

    if (userData0 == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = userData0?['name']?.toString() ?? user.email?.split('@')[0] ?? 'User';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildGreetingCard(),
        buildProgressCards(),
        buildPurchasedCoursesCard(),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> loadUserData() async {
    final user = auth.currentUser;
    if (user != null) {
      final snapshot = await database
          .child('users/${user.uid}/userdata/profile')
          .once();
      
      if (mounted && snapshot.snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
        setState(() {
          userName = data['name'] ?? user.email?.split('@')[0] ?? 'User';
        });
      }
    }
  }

  Widget buildProfileHeader() {
    return Padding(
      padding: EdgeInsets.all(getAdaptiveSize(12)), // Reduced from 16
      child: Row(
        children: [
          CircleAvatar(
            radius: getAdaptiveSize(20), // Reduced from 24
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              userName?[0].toUpperCase() ?? 'U',
              style: TextStyle(
                fontSize: getAdaptiveTextSize(16), // Reduced from 20
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hello, Welcome',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87, // Changed from grey to black87
                  ),
                ),
                Text(
                  userName ?? 'User',
                  style: TextStyle(
                    fontSize: getAdaptiveTextSize(14), // Reduced from 18
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary.withOpacity(0.9), // Changed to dark blue
                  ),
                ),
              ],
            ),
          ),
          // New Container for grouped buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildPointsBadge(),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.grey.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                buildNotificationButton(),
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  width: 1,
                  color: Colors.grey.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                buildAboutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;

    if (user == null) {
      Future.microtask(() => 
        Navigator.of(context).pushReplacementNamed('/login')
      );
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(  // Wrap Scaffold with AnnotatedRegion
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: Scaffold(
          key: scaffoldKey, // Add this line
          body: PageStorage(
            bucket: _bucket,
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(), // Enable swipe navigation
              onPageChanged: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              // Wrap each child in a Builder to ensure a new instance is created each time
              children: [
                Builder(
                  builder: (context) => SafeArea(
                    child: RefreshIndicator(
                      onRefresh: _refreshApp,
                      color: AppColors.primary,
                      child: buildHomeContent(),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) => const CourseScreen(key: PageStorageKey('course_screen')),
                ),
                Builder(
                  builder: (context) => const TrainingPage(
                    key: PageStorageKey('training_screen'),
                    practiceId: 'default_practice',
                    title: 'Daily Practice',
                    duration: '30',
                    practices: ['Basic Poses', 'Breathing', 'Meditation'],
                  ),
                ),
                Builder(
                  builder: (context) => const ProfileScreen(key: PageStorageKey('profile_screen')),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: selectedIndex,
            selectedItemColor: AppColors.secondary,
            unselectedItemColor: AppColors.textLight,
            backgroundColor: Colors.white,
            onTap: (index) {
              // Animate to the selected page when tapping bottom nav items
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book),
                label: 'Courses',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.fitness_center_outlined),
                activeIcon: Icon(Icons.fitness_center),
                label: 'Training',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
          endDrawer: NotificationDrawer(notificationService: notificationService),
          drawerEnableOpenDragGesture: true,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> getWeeklyData() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    return List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
      final points = _dailyPoints[dateKey] ?? 0;
      
      return {
        'day': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index],
        'minutes': points * 30, // Assuming 30 minutes per point
        'completed': points > 0,
        'date': dateKey,
        'points': points,
      };
    });
  }

  List<Map<String, dynamic>> getMonthlyData() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    
    return List.generate(daysInMonth, (index) {
      final day = DateTime(now.year, now.month, index + 1);
      final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
      final points = _dailyPoints[dateKey] ?? 0;
      
      return {
        'date': '${day.day}/${day.month}',
        'minutes': points * 30, // Assuming 30 minutes per point
        'completed': points > 0,
        'points': points,
      };
    });
  }

  void showGraphDetails(BuildContext context, String title, List<Map<String, dynamic>> data, Offset tapPosition) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: data.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item['completed'] 
                                  ? AppColors.primary 
                                  : AppColors.primary.withOpacity(0.1),
                            ),
                            child: Icon(
                              item['completed'] ? Icons.check : Icons.close,
                              color: item['completed'] ? Colors.white : AppColors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['day'] ?? item['date'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                if (item['completed']) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['minutes']} minutes of practice',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: item['completed'] 
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item['completed'] 
                                  ? 'Completed'
                                  : 'Missed',
                              style: TextStyle(
                                color: item['completed'] 
                                    ? AppColors.primary
                                    : Colors.grey,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to show the modal
  void showProgressDetails(BuildContext context, String title, String progress, List<Map<String, dynamic>> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  Text(
                    progress,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // List of activities
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: data.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final item = data[index];
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: item['completed'] 
                                ? AppColors.primary 
                                : AppColors.primary.withOpacity(0.1),
                          ),
                          child: Icon(
                            item['completed'] ? Icons.check : Icons.close,
                            color: item['completed'] ? Colors.white : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          item['day'] ?? item['date'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: item['completed'] 
                          ? Text(
                              '${item['minutes']} minutes of practice',
                              style: const TextStyle(color: AppColors.textLight),
                            )
                          : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: item['completed'] 
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            item['completed'] ? 'Completed' : 'Missed',
                            style: TextStyle(
                              color: item['completed'] 
                                  ? AppColors.primary
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new widget method
  Widget buildProgressCards() {
    return Container(
      transform: Matrix4.translationValues(0, -4.0, 0),
      child: Padding(
        padding: const EdgeInsets.only(
          top: 4.0,
          bottom: 12.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress Overview',
                    style: TextStyle(
                      fontSize: getAdaptiveTextSize(20), // Reduced from 24
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/progress'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Weekly Card
                  Expanded(
                    child: buildProgressCard(
                      title: 'This Week',
                      value: weeklyProgress,
                      icon: Icons.trending_up_rounded,
                      isFirst: true,
                      onTap: () => showProgressDetails(
                        context,
                        'Weekly Progress',
                        weeklyProgress,
                        getWeeklyData(),
                      ),
                    ),
                  ),
                  Container(
                    height: getAdaptiveSize(120), // Reduced from 140
                    width: 1,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  // Monthly Card
                  Expanded(
                    child: buildProgressCard(
                      title: 'This Month',
                      value: monthlyProgress,
                      icon: Icons.calendar_month_rounded,
                      isFirst: false,
                      onTap: () => showProgressDetails(
                        context,
                        'Monthly Progress',
                        monthlyProgress,
                        getMonthlyData(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildProgressCard({
    required String title,
    required String value,
    required IconData icon,
    required bool isFirst,
    required VoidCallback onTap,
  }) {
    // Check if data is actually loading
    if (_isLoadingProgress && _dailyPoints.isEmpty) {
      return _buildProgressCardSkeleton(isFirst);
    }

    final controllerKey = '${title}_progress';
    
    // Initialize the controller if it doesn't exist
    if (_progressCardControllers[controllerKey] == null) {
      _progressCardControllers[controllerKey] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..forward();
    }

    final progressAnimation = CurvedAnimation(
      parent: _progressCardControllers[controllerKey]!,
      curve: Curves.easeOutBack,
    );

    // Calculate graph data based on points history
    final graphData = _calculateGraphData(isFirst);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(32) : Radius.zero,
            right: !isFirst ? const Radius.circular(32) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            SizedBox(
              height: 140, // Increased height for better visibility
              width: double.infinity, // Ensure full width
              child: RepaintBoundary( // <-- insert RepaintBoundary here
                child: CustomPaint(
                  painter: graphData.isEmpty || totalPoints == 0 
                    ? FlatProgressPainter()
                    : CurvedProgressGraphPainter(
                        progress: progressAnimation.value,
                        color: AppColors.secondary, // Changed from primary to secondary
                        graphData: graphData,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  ' days completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<double> _calculateGraphData(bool isWeekly) {
    final now = DateTime.now();
    List<double> data = [];
    
    if (isWeekly) {
      // Weekly data - last 7 days
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      double maxPoints = 0;

      // First pass to find max points for normalization
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
        final points = _dailyPoints[dateKey] ?? 0;
        maxPoints = points > maxPoints ? points.toDouble() : maxPoints;
      }

      // Second pass to normalize data
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
        final points = _dailyPoints[dateKey] ?? 0;
        // Normalize between 0 and 1, but ensure non-zero values are visible
        data.add(maxPoints > 0 ? (points / maxPoints) : 0);
      }
    } else {
      // Monthly data
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      double maxPoints = 0;

      // First pass to find max points
      for (int i = 1; i <= daysInMonth; i++) {
        final day = DateTime(now.year, now.month, i);
        final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
        final points = _dailyPoints[dateKey] ?? 0;
        maxPoints = points > maxPoints ? points.toDouble() : maxPoints;
      }

      // Second pass to normalize data
      for (int i = 1; i <= daysInMonth; i++) {
        final day = DateTime(now.year, now.month, i);
        final dateKey = '${day.toIso8601String().split('T')[0]}T00:00:00.000';
        final points = _dailyPoints[dateKey] ?? 0;
        // Normalize between 0 and 1, but ensure non-zero values are visible
        data.add(maxPoints > 0 ? (points / maxPoints) : 0);
      }
    }

    return data;
  }

  Future<void> loadUserProfile() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        database
            .child('users/${user.uid}')
            .onValue
            .listen((event) {
          if (mounted && event.snapshot.value != null) {
            final userData = Map<String, dynamic>.from(event.snapshot.value as Map);
            setState(() {
              userName = userData['name'] ?? user.email?.split('@')[0] ?? 'User';
              totalPoints = userData['userdata']?['totalpoints'] ?? 0;
            });
            debugPrint('Loaded user name: $userName');
          }
        }, onError: (error) {
          debugPrint('Error loading user data: $error');
          if (mounted) {
            setState(() {
              userName = user.email?.split('@')[0] ?? 'User';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error in loadUserProfile: $e');
    }
  }



  Widget buildGreetingCard() {
    return AnimatedBuilder(
      animation: cardScale,
      builder: (context, child) => Transform.scale(
        scale: cardScale.value,
        child: Card(
          margin: EdgeInsets.only(
            left: getAdaptiveSize(12.0),  // Reduced from 16
            right: getAdaptiveSize(12.0), // Reduced from 16
            top: getAdaptiveSize(8.0),    // Reduced from 12
            bottom: getAdaptiveSize(4.0),
          ),
          elevation: 15,
          shadowColor: AppColors.tertiary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Container(
            width: double.infinity, // Use full width instead of fixed width
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.95),  // Medium dark blue
                  AppColors.tertiary,                     // Lighter blue, but not too light
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: getAdaptiveSize(16), // Reduced from 20
                    vertical: getAdaptiveSize(20),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                           
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Remove buildFocusItem method as it's no longer needed

  Widget buildPointsBadge() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          height: getAdaptiveSize(32), // Reduced from 40
          padding: EdgeInsets.symmetric(horizontal: getAdaptiveSize(12), vertical: getAdaptiveSize(4)),
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: AppColors.secondary,
                size: getAdaptiveSize(20),
              ),
              const SizedBox(width: 6),
              Text(
                '$totalPoints',
                style: TextStyle(
                  fontSize: getAdaptiveTextSize(16),
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAnimatedQuote() {
    const quote = "Yoga is the art of waking up to yourself every day.";
    return AnimatedBuilder(
      animation: quoteController,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.amber.withOpacity(0.5),
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontSize: getAdaptiveTextSize(15), // Slightly smaller
                fontWeight: FontWeight.w500,
                height: 1.3, // Tighter line height
                letterSpacing: 0.2,
                fontStyle: FontStyle.italic,
              ),
              children: List.generate(
                quote.length,
                (index) => TextSpan(
                  text: quote[index],
                  style: TextStyle(
                    color: Colors.white.withOpacity(characterOpacities[index].value),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Material buildAboutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            final snapshot = await database.child('profile').get();
            
            if (!mounted) return;
            
            if (snapshot.exists && snapshot.value != null) {
              final profileData = Map<String, dynamic>.from(snapshot.value as Map);
              
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Stack(
                    children: [
                      // Main Content
                      CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Profile Header
                          SliverAppBar(
                            expandedHeight: 200,
                            backgroundColor: Colors.transparent,
                            pinned: false,
                            flexibleSpace: FlexibleSpaceBar(
                              background: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withOpacity(0.8),
                                      AppColors.secondary,
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Decorative patterns
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: ProfilePatternPainter(),
                                      ),
                                    ),
                                    // Profile Image
                                    Center(
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 4,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: profileData['image'] != null
                                              ? Image.network(
                                                  profileData['image'],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _buildProfilePlaceholder(),
                                                )
                                              : _buildProfilePlaceholder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Profile Content
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                children: [
                                  // Name with verification badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        profileData['name '] ?? 'User',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.verified,
                                        color: AppColors.primary,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Description Card
                                  if (profileData['description'] != null)
                                    _buildInfoCard(
                                      'About',
                                      profileData['description'],
                                      Icons.person_outline,
                                    ),
                                  const SizedBox(height: 24),
                                  // Achievements Card
                                  if (profileData['achivements'] != null)
                                    _buildInfoCard(
                                      'Achievements',
                                      profileData['achivements'],
                                      Icons.emoji_events_outlined,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Close Button
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Handle Bar
                      Positioned(
                        top: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error loading profile: $e');
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3), // Increased opacity
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            color: Colors.white, // Changed to white
            size: 22, // Slightly larger
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Icon(
        Icons.person,
        size: 60,
        color: AppColors.primary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.grey[800],
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.arrow_right, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                item,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Future<void> loadActivityData() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        // Create a broadcast stream for activities
        final activitiesStream = database
            .child('users/${user.uid}/userdata/activities')
            .onValue
            .asBroadcastStream();

        // Listen to the broadcast stream
        _activitiesSubscription?.cancel();
        _activitiesSubscription = activitiesStream.listen((event) {
          if (mounted && event.snapshot.value != null) {
            final activitiesMap = Map<String, dynamic>.from(event.snapshot.value as Map);
            final activities = convertActivitiesData(activitiesMap);
            
            // Process weekly data
            final weeklyData = processActivities(
              activities,
              DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
              const Duration(days: 7),
            );

            // Process monthly data
            final monthlyData = processActivities(
              activities,
              DateTime(DateTime.now().year, DateTime.now().month, 1),
              const Duration(days: 30),
            );

            setState(() {
              weeklyActivities = weeklyData;
              monthlyActivities = monthlyData;
              weeklyProgress = '${weeklyData.length}/7';
              monthlyProgress = '${monthlyData.length}/${DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day}';
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading activity data: $e');
    }
  }

  Map<String, Map<String, dynamic>> convertActivitiesData(Map<String, dynamic> rawData) {
    final convertedData = <String, Map<String, dynamic>>{};
    
    rawData.forEach((key, value) {
      if (value is Map) {
        final activityData = Map<String, dynamic>.from(value);
        // Convert timestamp to date string for key
        if (activityData['date'] != null) {
          final date = DateTime.parse(activityData['date']);
          final dateKey = date.toIso8601String().split('T')[0];
          
          convertedData[dateKey] = {
            'completed': activityData['completed'] ?? false,
            'duration': 30, // Default duration if not specified
            'title': activityData['title'] ?? 'Yoga Practice',
            'points': activityData['points'] ?? 0,
          };
        }
      }
    });
    
    return convertedData;
  }

  Map<String, dynamic> processActivities(
    Map<String, dynamic> activities,
    DateTime startDate,
    Duration period,
  ) {
    final endDate = startDate.add(period);
    final filteredActivities = <String, dynamic>{};

    activities.forEach((dateKey, value) {
      try {
        final activityDate = DateTime.parse(dateKey);
        if (activityDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
            activityDate.isBefore(endDate)) {
          filteredActivities[dateKey] = value;
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    });

    return filteredActivities;
  }

  Future<void> _refreshApp() async {
    try {
      setState(() {
        _isLoading = true;
        _isLoadingProgress = true;
      });

      final user = auth.currentUser;
      if (user == null) return;

      // Fetch all data concurrently
      await Future.wait([
        // Points history
        database
            .child('users/${user.uid}/points_history')
            .get()
            .then((snapshot) {
          if (snapshot.exists && snapshot.value != null) {
            final data = Map<String, dynamic>.from(snapshot.value as Map);
            _processDailyPoints(data);
          }
        }),

        // Activities
        database
            .child('users/${user.uid}/userdata/activities')
            .get()
            .then((snapshot) {
          if (snapshot.exists && snapshot.value != null) {
            final activitiesMap = Map<String, dynamic>.from(snapshot.value as Map);
            final activities = convertActivitiesData(activitiesMap);
            _processActivitiesUpdate(activities);
          }
        }),

        // User profile and other data
        loadUserProfile(),
        _loadPurchasedCoursesCount(),
        _loadPurchasedPracticesCount(),
        _loadFeaturedPractices(),
      ]);

      _updateProgress();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing app: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingProgress = false;
        });
      }
    }
  }

// Add this new method
  Future<void> loadPurchasedCourses() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        // First get all payments for this user
        final paymentsSnapshot = await database
            .child('payments')
            .orderByChild('userId')
            .equalTo(user.uid)
            .once();

        if (paymentsSnapshot.snapshot.value != null) {
          final payments = Map<String, dynamic>.from(paymentsSnapshot.snapshot.value as Map);
          
          // Filter verified payments and extract course IDs
          final verifiedCourseIds = payments.values
              .where((payment) => payment['status'] == 'verified')
              .map((payment) => payment['courseId'] as String)
              .toSet();

          if (verifiedCourseIds.isNotEmpty) {
            // Get course details for each verified purchase
            final coursesList = <Map<String, dynamic>>[];
            
            for (final courseId in verifiedCourseIds) {
              final courseSnapshot = await database
                  .child('courses/$courseId')
                  .once();
              
              if (courseSnapshot.snapshot.value != null) {
                final courseData = Map<String, dynamic>.from(
                  courseSnapshot.snapshot.value as Map
                );
                
                // Add courseId to the course data
                courseData['id'] = courseId;
                coursesList.add(courseData);
              }
            }

            if (mounted) {
              setState(() {
                purchasedCourses = coursesList;
                _isLoading = false;
              });
            }
          } else {
            setState(() {
              purchasedCourses = [];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading purchased courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Optional: Add this helper method to check if a course is purchased
  Future<bool> isCoursePurchased(String courseId) async {
  try {
    final user = auth.currentUser;
    if (user != null) {
      final snapshot = await database
          .child('payments')
          .orderByChild('userId')
          .equalTo(user.uid)
          .once();

      if (snapshot.snapshot.value != null) {  // Changed this line
        final payments = Map<String, dynamic>.from(snapshot.snapshot.value as Map);  // And this line
        return payments.values.any((payment) => 
          payment['courseId'] == courseId && 
          payment['status'] == 'verified'
        );
      }
    }
    return false;
  } catch (e) {
    debugPrint('Error checking course purchase: $e');
    return false;
  }
}

  // Add this new widget method
  Widget buildPurchasedCoursesCard() {
    if (purchasedCourses.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Your Courses',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ),
        ...purchasedCourses.map((course) {
          return GestureDetector(
            onTap: () {
              // Navigate to course details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseScreen(), // Remove courseId parameter
                ),
              );
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      course['image'],
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      course['title'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // Add this new method
  Widget buildPurchasedCoursesSection() {
    if (purchasedCourses.isEmpty) return const SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: getAdaptiveSize(12)), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Courses',
                style: TextStyle(
                  fontSize: getAdaptiveTextSize(20), // Reduced from 24
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/courses'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: getAdaptiveSize(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: getAdaptiveTextSize(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: getAdaptiveSize(14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: getAdaptiveSize(12)),
          SizedBox(
            height: getAdaptiveSize(180), // Reduced from 220
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: purchasedCourses.length,
              itemBuilder: (context, index) {
                final course = purchasedCourses[index];
                return Container(
                  width: getAdaptiveSize(160), // Reduced from 200
                  margin: EdgeInsets.only(
                    right: getAdaptiveSize(16),
                    left: index == 0 ? 0 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CourseScreen(),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: Image.network(
                              course['image'],
                              height: getAdaptiveSize(100), // Reduced from 120
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(getAdaptiveSize(8)), // Reduced from 12
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course['title'],
                                  style: TextStyle(
                                    fontSize: getAdaptiveTextSize(14), // Reduced from 16
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: getAdaptiveSize(8)),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: getAdaptiveSize(8),
                                        vertical: getAdaptiveSize(4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.play_circle_outline,
                                            size: getAdaptiveSize(16),
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${course['lessons'] ?? 0} Lessons',
                                            style: TextStyle(
                                              fontSize: getAdaptiveTextSize(12),
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w500,
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
            ),
          ),
        ],
      ),
    );
  }

  Future<void> checkForNewPoll() async {
    try {
      final user = auth.currentUser;
      if (user != null) {
        // Check for new poll
        final pollSnapshot = await database.child('poll').once();
        if (pollSnapshot.snapshot.value != null) {
          final pollData = pollSnapshot.snapshot.value as Map<Object?, Object?>;
          final pollTimestamp = DateTime.tryParse(pollData['created_at']?.toString() ?? '');
          
          // Check user's last poll response
          final responseSnapshot = await database
              .child('poll/responses/${user.uid}')
              .once();
          
          setState(() {
            _hasNewPoll = pollTimestamp != null && 
                         (responseSnapshot.snapshot.value == null ||
                          (_lastPollCheck != null && pollTimestamp.isAfter(_lastPollCheck!)));
          });
        }
      }
    } catch (e) {
      print('Error checking for new poll: $e');
    }
  }

  Widget buildHomeContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Premium Top Header - Updated
        SliverToBoxAdapter(
          child: Column(
            children: [
              buildProfileTopSheet(),
              const SizedBox(height: 16), // Add some spacing after the header
            ],
          ),
        ),
        
        // Progress Cards with Glass Effect
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4), // Changed from 10 to 4
            child: buildProgressCards(),
          ),
        ),

        // Featured Section
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Quick Access',
                    style: TextStyle(
                      fontSize: getAdaptiveTextSize(18),
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 170,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildPracticeCard(),
                      _buildCourseCard(),
                      _buildPollCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Purchased Courses with Enhanced UI
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 100),
            child: buildPurchasedCoursesSection(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (backgroundColor ?? AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon, 
                    color: iconColor ?? AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Add this method after initState
  Future<void> _loadFeaturedPractices() async {
  try {
    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('practice')
        .orderByChild('featured')
        .equalTo(true)
        .once();

    if (mounted && snapshot.snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final practices = <Map<String, dynamic>>[];
      
      data.forEach((key, value) {
        if (value is Map) {
          final practice = Map<String, dynamic>.from(value);
          practice['id'] = key;
          practices.add(practice);
        }
      });

      setState(() {
        _featuredPractices = practices;
        _isLoadingPractices = false;
      });
    } else {
      setState(() {
        _featuredPractices = [];
        _isLoadingPractices = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading featured practices: $e');
    if (mounted) {
      setState(() {
        _isLoadingPractices = false;
      });
    }
  }
}

// Replace the existing _buildFeaturedList method
  Widget _buildFeaturedList() {
    if (_isLoadingPractices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_featuredPractices.isEmpty) {
      return const Center(
        child: Text('No featured practices available'),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _featuredPractices.length,
      itemBuilder: (context, index) {
        final practice = _featuredPractices[index];
        final steps = Map<String, dynamic>.from(
          practice.entries
              .where((e) => e.key.startsWith('step'))
              .fold({}, (map, e) => map..addAll({e.key: e.value}))
        );
        
        // Get first step's model URL for thumbnail
        final firstStep = steps.values.first as Map;
        final modelUrl = firstStep['model'] as String? ?? '';
        
        return Container(
          width: 280,
          margin: EdgeInsets.only(right: index == _featuredPractices.length - 1 ? 0 : 16),
          child: GestureDetector(
            onTap: () => _showPracticeDetails(practice),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Background Image with Overlay
                        if (modelUrl.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              modelUrl,
                              fit: BoxFit.cover,
                              color: Colors.black.withOpacity(0.3),
                              colorBlendMode: BlendMode.darken,
                            ),
                          ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${steps.length} poses',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                practice['yoga'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () => _startPractice(practice),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_filled_rounded),
                                    SizedBox(width: 8),
                                    Text(
                                      'Start Practice',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
        );
      },
    );
  }

  void _showPracticeDetails(Map<String, dynamic> practice) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    practice['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    practice['description'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: getAdaptiveTextSize(15),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Practice details
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'What you\'ll practice:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    (practice['practices'] as List).length,
                    (index) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        practice['practices'][index] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Start button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startPractice(practice);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Start Practice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPractice(Map<String, dynamic> practice) {
    final steps = Map<String, dynamic>.from(
      practice.entries
          .where((e) => e.key.startsWith('step'))
          .fold({}, (map, e) => map..addAll({e.key: e.value}))
    );
    
    final practices = steps.values
        .map((step) => (step as Map)['pose1'].toString())
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrainingPage(
          practiceId: practice['id'] as String,
          title: practice['yoga'] as String,
          duration: '${steps.length * 2} min', // Assuming 2 min per step
          practices: practices,
        ),
      ),
    ).then((_) => _refreshApp()); // Handle completion this way instead
  }

  String getMotivationalMessage() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return "Mondays are for fresh starts and bold steps.";
      case DateTime.tuesday:
        return "Turn dreams into plans—Tuesday is yours.";
      case DateTime.wednesday:
        return "Midweek magic—Wednesday is your momentum.";
      case DateTime.thursday:
        return "Stay steady; Thursday brings you closer.";
      case DateTime.friday:
        return "Celebrate the wins—Friday is your triumph.";
      case DateTime.saturday:
        return "Saturday shines for rest and renewal.";
      case DateTime.sunday:
        return "Breathe deeply—Sunday is your sanctuary.";
      default:
        return "Time to center yourself";
    }
  }

  // Add this new method
  String getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Today';
    }
  }

  Widget buildProfileTopSheet() {
  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary,
          AppColors.secondary,
        ],
      ),
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(32),
      ),
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row with Profile and Actions
          Padding(
            padding: EdgeInsets.all(getAdaptiveSize(16)),
            child: Row(
              children: [
                // Profile Card with Transparent Background
                Container(
                  padding: EdgeInsets.all(getAdaptiveSize(12)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: getAdaptiveSize(40),
                        height: getAdaptiveSize(40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            userName?[0].toUpperCase() ?? 'U',
                            style: TextStyle(
                              fontSize: getAdaptiveTextSize(18),
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: getAdaptiveSize(12)),
                      Text(
                        userName ?? 'User',
                        style: TextStyle(
                          fontSize: getAdaptiveTextSize(16),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Action Buttons
                Row(
                  children: [
                    buildNotificationButton(),
                    SizedBox(width: getAdaptiveSize(8)),
                    buildAboutButton(),
                  ],
                ),
              ],
            ),
          ),
          // Progress Gauge Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 130,
                  width: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      // Progress arc
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: GaugeProgressPainter(
                            progress: _todayProgress / _todayGoal,
                            colors: [const Color.fromARGB(255, 255, 255, 255), const Color.fromARGB(255, 157, 231, 255), const Color.fromARGB(255, 209, 255, 250)],
                            strokeWidth: 12,
                          ),
                        ),
                      ),
                      // Centered progress text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${((_todayProgress / _todayGoal) * 100).toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Today",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Centered progress message
                Center(
                  child: Text(
                    _todayProgress >= 100 
                        ? "Great job! Daily goal achieved!" 
                        : "Keep going! ${100 - _todayProgress}% to goal",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Stats Card
          if (_purchasedCoursesCount > 0 || _purchasedPracticesCount > 0 || totalPoints > 0)
            Padding(
              padding: EdgeInsets.all(getAdaptiveSize(16)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: getAdaptiveSize(20),
                  vertical: getAdaptiveSize(16),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickStat('Courses', _purchasedCoursesCount.toString()),
                    _buildDivider(),
                    _buildQuickStat('Practices', _purchasedPracticesCount.toString()),
                    _buildDivider(),
                    _buildQuickStat('Points', totalPoints.toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: getAdaptiveTextSize(20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: getAdaptiveSize(4)),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: getAdaptiveTextSize(14),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: getAdaptiveSize(24),
      width: 1,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Future<void> _loadPurchasedCoursesCount() async {
    if (mounted) {
      final count = await _paymentService.getPurchasedCoursesCount();
      setState(() {
        _purchasedCoursesCount = count;
      });
    }
  }

  // Add this method with other class methods
Future<void> _loadPurchasedPracticesCount() async {
  if (mounted) {
    final count = await _paymentService.getPurchasedPracticesCount();
    setState(() {
      _purchasedPracticesCount = count;
    });
  }
}

  // Add this method in your HomeScreen state class
Widget _buildFeatureCards() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why Choose Yogam?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _buildFeatureCard(
              icon: Icons.self_improvement,
              title: 'Expert Guidance',
              description: 'Learn from certified yoga instructors with years of experience',
              color: Colors.blue,
            ),
            _buildFeatureCard(
              icon: Icons.video_library,
              title: 'HD Video Content',
              description: 'High-quality video lessons for clear instruction',
              color: Colors.green,
            ),
            _buildFeatureCard(
              icon: Icons.timeline,
              title: 'Progress Tracking',
              description: 'Monitor your improvement with detailed progress tracking',
              color: Colors.orange,
            ),
            _buildFeatureCard(
              icon: Icons.accessibility_new,
              title: 'All Levels',
              description: 'Courses for beginners to advanced practitioners',
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Our Training Approach',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildTrainingCard(
              title: 'Holistic Development',
              description: 'Focus on mind, body, and spiritual wellness through integrated practices',
              icon: Icons.spa,
            ),
            _buildTrainingCard(
              title: 'Personalized Learning',
              description: 'Adaptive courses that match your skill level and goals',
              icon: Icons.person_outline,
            ),
            _buildTrainingCard(
              title: 'Community Support',
              description: 'Join a community of yoga enthusiasts and share your journey',
              icon: Icons.group,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildFeatureCard({
  required IconData icon,
  required String title,
  required String description,
  required Color color,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {}, // Optional: Add interaction
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildTrainingCard({
  required String title,
  required String description,
  required IconData icon,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {}, // Optional: Add interaction
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _loadPointsHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pointsRef = FirebaseDatabase.instance
          .ref()
          .child('users/${user.uid}/points_history');

      final snapshot = await pointsRef.get();
      if (!mounted) return;
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Process the points history
        final dailyPoints = <String, int>{};
        
        data.forEach((key, value) {
          if (value is Map) {
            final entry = Map<String, dynamic>.from(value);
            final timestamp = entry['timestamp'] as String;
            final points = entry['points'] as int;
            
            // Aggregate points by day
            dailyPoints.update(
              timestamp,
              (existing) => existing + points,
              ifAbsent: () => points,
            );
          }
        });

        setState(() {
          _pointsHistory = data;
          _dailyPoints = dailyPoints;
          _isLoadingProgress = false;
          
          // Update progress strings
          weeklyProgress = _calculateWeeklyProgress();
          monthlyProgress = _calculateMonthlyProgress();
          _calculateTodayProgress();  // Update today's progress
        });
      } else {
        setState(() {
          _isLoadingProgress = false;
          _dailyPoints = {};
        });
      }
    } catch (e) {
      debugPrint('Error loading points history: $e');
      if (mounted) {
        setState(() {
          _isLoadingProgress = false;
        });
      }
    }
  }

  String _calculateWeeklyProgress() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int daysWithActivity = 0;

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final dateKey = day.toIso8601String().split('T')[0];
      if (_dailyPoints.containsKey('${dateKey}T00:00:00.000')) {
        daysWithActivity++;
      }
    }

    return '$daysWithActivity/7';
  }

  String _calculateMonthlyProgress() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int daysWithActivity = 0;

    for (int i = 1; i <= daysInMonth; i++) {
      final day = DateTime(now.year, now.month, i);
      final dateKey = day.toIso8601String().split('T')[0];
      if (_dailyPoints.containsKey('${dateKey}T00:00:00.000')) {
        daysWithActivity++;
      }
    }

    return '$daysWithActivity/$daysInMonth';
  }

  // Add this method to calculate today's progress
  void _calculateTodayProgress() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayKey = '${today}T00:00:00.000';
    
    // Calculate today's progress based on points earned today
    final todayPoints = _dailyPoints[todayKey] ?? 0;
    
    // Convert points to a percentage (assuming 10 points = 100%)
    setState(() {
      _todayProgress = (todayPoints / 10 * 100).clamp(0, 100).toInt();
    });
  }

  Widget _buildProgressCardSkeleton(bool isFirst) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(32) : Radius.zero,
          right: !isFirst ? const Radius.circular(32) : Radius.zero,
        ),
      ),
      child: ShimmerLoading(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 80,
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

  Widget _buildFeaturedCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: screenWidth * 0.7,
      height: 170, // Fixed height to prevent overflow
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to specific yoga session
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TrainingPage(
                  practiceId: 'featured_${title.toLowerCase().replaceAll(" ", "_")}',
                  title: title,
                  duration: '30 min',
                  practices: const ['Basic Poses', 'Breathing', 'Meditation'],
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // Reduced padding
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24, // Reduced size
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20, // Reduced font size
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4), // Reduced spacing
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14, // Reduced font size
                  ),
                ),
                const SizedBox(height: 12), // Reduced spacing
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4, // Reduced padding
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '30 min',
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Added font size
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: color,
                        size: 20, // Reduced size
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMorningYogaCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.orange,
          Colors.orange.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.orange.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Morning Yoga',
      subtitle: 'Energize your day',
      duration: '20 min',
      icon: Icons.wb_sunny_rounded,
      color: Colors.orange,
      onTap: () => _startMorningYoga(),
    ),
  );
}

Widget _buildEveningFlowCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.indigo,
          Colors.indigo.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Evening Flow',
      subtitle: 'Unwind & relax',
      duration: '25 min',
      icon: Icons.nightlight_round,
      color: Colors.indigo,
      onTap: () => _startEveningFlow(),
    ),
  );
}

Widget _buildMeditationCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.teal,
          Colors.teal.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.teal.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Meditation',
      subtitle: 'Find inner peace',
      duration: '15 min',
      icon: Icons.self_improvement_rounded,
      color: Colors.teal,
      onTap: () => _startMeditation(),
    ),
  );
}

Widget _buildFeatureCardContent({
  required String title,
  required String subtitle,
  required String duration,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _startMorningYoga() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const TrainingPage(
        practiceId: 'morning_yoga',
        title: 'Morning Yoga',
        duration: '20 min',
        practices: [
          'Sun Salutation',
          'Standing Poses',
          'Energy Breathing',
          'Morning Stretches'
        ],
      ),
    ),
  );
}

void _startEveningFlow() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const TrainingPage(
        practiceId: 'evening_flow',
        title: 'Evening Flow',
        duration: '25 min',
        practices: [
          'Gentle Stretches',
          'Restorative Poses',
          'Deep Breathing',
          'Relaxation'
        ],
      ),
    ),
  );
}

void _startMeditation() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const TrainingPage(
        practiceId: 'meditation',
        title: 'Meditation',
        duration: '15 min',
        practices: [
          'Mindful Breathing',
          'Body Scan',
          'Guided Meditation',
          'Silent Reflection'
        ],
      ),
    ),
  );
}

Widget _buildPracticeCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.orange,
          Colors.orange.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.orange.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Daily Practice',
      subtitle: 'Start your yoga journey',
      duration: '', // Removed the "30 min" text
      icon: Icons.self_improvement,
      color: Colors.orange,
      onTap: () {
        _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    ),
  );
}

Widget _buildCourseCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.indigo,
          Colors.indigo.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.indigo.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Courses',
      subtitle: 'Browse all courses',
      duration: '$_purchasedCoursesCount enrolled',
      icon: Icons.menu_book_rounded,
      color: Colors.indigo,
      onTap: () {
        _pageController.animateToPage(
          1, // Index of CourseScreen
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
    ),
  );
}

Widget _buildPollCard() {
  return Container(
    width: screenWidth * 0.7,
    height: 170,
    margin: const EdgeInsets.only(right: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.teal,
          Colors.teal.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.teal.withOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _buildFeatureCardContent(
      title: 'Daily Poll',
      subtitle: 'Share your thoughts',
      duration: _hasNewPoll ? 'New poll!' : 'Vote now',
      icon: Icons.poll_rounded,
      color: Colors.teal,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PollScreen(),
          ),
        );
      },
    ),
  );
}

  Future<void> _initializeStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = LocalStorageService(prefs);
    setState(() {
      _lastViewedVideo = _storageService.getLastViewedVideo();
    });
  }

  // Add this new method to process daily points
  void _processDailyPoints(Map<String, dynamic> data) {
    final dailyPoints = <String, int>{};
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    data.forEach((key, value) {
      if (value is Map) {
        final entry = Map<String, dynamic>.from(value);
        final timestamp = entry['timestamp'] as String? ?? '';
        final points = entry['points'] as int? ?? 0;
        final date = timestamp.split('T')[0];
        
        dailyPoints.update(
          date,
          (existing) => existing + points,
          ifAbsent: () => points,
        );

        // If it's today's points, update the gauge progress
        if (date == today) {
          _todayProgress = ((dailyPoints[date] ?? 0) / _todayGoal * 100).clamp(0, 100).toInt();
        }
      }
    });

    if (mounted) {
      setState(() {
        _dailyPoints = dailyPoints;
        _isLoadingProgress = false;
      });
    }
  }

  void _setupProgressListeners() {
    final user = auth.currentUser;
    if (user == null) return;

    // Listen to daily points updates
    database
        .child('users/${user.uid}/points_history')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      _processDailyPoints(data);
      _updateProgress();
    }, onError: (error) {
      debugPrint('Error listening to points history: $error');
    });

    // Listen to activities updates
    database
        .child('users/${user.uid}/userdata/activities')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      
      final activitiesMap = Map<String, dynamic>.from(event.snapshot.value as Map);
      final activities = convertActivitiesData(activitiesMap);
      _processActivitiesUpdate(activities);
    }, onError: (error) {
      debugPrint('Error listening to activities: $error');
    });
  }

  void _processActivitiesUpdate(Map<String, dynamic> activities) {
    final weeklyData = processActivities(
      activities,
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
      const Duration(days: 7),
    );

    final monthlyData = processActivities(
      activities,
      DateTime(DateTime.now().year, DateTime.now().month, 1),
      const Duration(days: 30),
    );

    if (mounted) {
      setState(() {
        weeklyActivities = weeklyData;
        monthlyActivities = monthlyData;
        weeklyProgress = '${weeklyData.length}/7';
        monthlyProgress = '${monthlyData.length}/${DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day}';
      });
    }
  }

  void _updateProgress() {
    if (!mounted) return;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayKey = '${today}T00:00:00.000';
    final todayPoints = _dailyPoints[todayKey] ?? 0;

    setState(() {
      _todayProgress = (todayPoints / _todayGoal * 100).clamp(0, 100).toInt();
      weeklyProgress = _calculateWeeklyProgress();
      monthlyProgress = _calculateMonthlyProgress();
    });

    // Trigger animation for progress updates
    progressController.forward(from: 0.0);
    
    // Update progress card animations
    _progressCardControllers.values.forEach((controller) {
      controller.forward(from: 0.0);
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      await _controller.loadPractices();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading practices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

extension on DatabaseEvent {
  get value => null;
}

class AnimatedProgressGraph extends StatelessWidget {
  final double progress;
  final bool isWeekly;
  final Color color;
  final List<double> graphData;  // Changed from data to graphData

  const AnimatedProgressGraph({
    super.key,
    required this.progress,
    required this.isWeekly,
    required this.color,
    required this.graphData,  // Changed from data to graphData and made required
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CurvedProgressGraphPainter(
        progress: progress,
        color: color,
        graphData: graphData,
      ),
    );
  }
}

// Find the CurvedProgressGraphPainter class and replace it with:
class CurvedProgressGraphPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<double> graphData;

  CurvedProgressGraphPainter({
    required this.progress,
    required this.color,
    required this.graphData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    
    // Guard against insufficient graph data to avoid division by zero
    if (graphData.length < 2) {
      final fallbackPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = 3.0;
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fallbackPaint);
      return;
    }

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final double stepX = size.width / (graphData.length - 1);
    final double maxY = size.height * 0.8;
    final double minY = size.height * 0.15;
    final double amplitude = (maxY - minY) * 0.6;

    List<Offset> points = [];
    for (int i = 0; i < graphData.length; i++) {
      final x = i * stepX;
      if (graphData[i] > 0) {
        final baseY = minY + amplitude * 0.5;
        const waveFrequency = pi / 1.5;
        final phaseShift = progress * pi;
        
        final waveY = baseY +
                     (sin(i * waveFrequency + phaseShift) * amplitude * 0.3) +
                     (cos(i * waveFrequency * 0.5 + phaseShift) * amplitude * 0.2);
        points.add(Offset(x, waveY));
      } else {
        points.add(Offset(x, maxY));
      }
    }

    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        
        final controlPoint1 = Offset(
          current.dx + (next.dx - current.dx) * 0.5,
          current.dy,
        );
        final controlPoint2 = Offset(
          current.dx + (next.dx - current.dx) * 0.5,
          next.dy,
        );

        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy,
          controlPoint2.dx, controlPoint2.dy,
          next.dx, next.dy,
        );
      }
    }

    // Draw main line and dots
    canvas.drawPath(path, mainPaint);
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if (graphData[i] > 0) {
        canvas.drawCircle(points[i], 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CurvedProgressGraphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.graphData.length != graphData.length;
  }
}

class FlatProgressPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 3.0;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedSearchIcon extends StatelessWidget {
  final Color iconColor;  // Add this property
  final double iconSize;  // Add this property

  const _AnimatedSearchIcon({
    required this.iconColor,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.search,
        color: iconColor,  // Use the property here
        size: iconSize,    // Use the property here
      ),
    );
  }
}

// Add this custom painter class outside of _HomeScreenState
class GaugeProgressPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double strokeWidth;

  GaugeProgressPainter({
    required this.progress,
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final radius = min(size.width, size.height)/2;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth/2);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi/2 + 2*pi*progress,
      colors: colors,
      stops: [0.0, 0.5, 1.0],
    );
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);
    
    canvas.drawArc(
      rect,
      -pi/2,
      2*pi*progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}