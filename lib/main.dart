import 'package:flutter/material.dart';
import 'dart:async';
import 'screens/login_page.dart';
import 'screens/home_screen.dart';
import 'screens/practice_history_page.dart';
import 'theme/colors.dart';  // Update this import
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'package:provider/provider.dart';
import 'controllers/home_controller.dart';
import 'package:http/http.dart' as http;
import 'utils/size_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/version_service.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';  // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add this to set status bar color and style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary, // Set status bar color
      statusBarIconBrightness: Brightness.light, // Icons should be light/white
      statusBarBrightness: Brightness.dark, // For iOS
    ),
  );
  
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
        name: 'YogaApp' // Remove comma here
      );
    }
    
    final notificationService = NotificationService();
    await notificationService.init();
    
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Handle initialization error
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeController()),
        // Add other providers if needed
      ],
      child: MaterialApp(
        title: 'Yoga Ugam', // Changed from 'Yoga App' to 'Yoga Ugam'
        initialRoute: '/',  // Change this line - remove home property
        onGenerateRoute: (settings) {
          debugPrint('Navigating to: ${settings.name}'); // Add debug logging
          // Define custom page transitions
          Widget page;
          switch (settings.name) {
            case '/':
              page = const SplashScreen(); // Remove const
              break;
            case '/login':
              page = const LoginPage();
              break;
            case '/home':
              page = const HomeScreen();
              break;
            case '/progress':
              page = const PracticeHistoryPage();
              break;
            default:
              page = const SplashScreen(); // Remove const
          }

          // Use custom transition for all routes
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => page,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 200),
          );
        },
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: AppColors.darkGreen,          // Update these color references
            secondary: AppColors.mediumDarkGreen,
            tertiary: AppColors.lightGreen,
            surface: Colors.white,
            error: Colors.red,
          ),
          scaffoldBackgroundColor: AppColors.veryLightGreen,  
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
           ),
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 8,
            shadowColor: AppColors.primaryWithShadow, // Updated to use new constant
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAliasWithSaveLayer, // Add this line
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
            headlineMedium: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
            titleLarge: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(
              color: AppColors.textDark, // Changed from textBody to textDark
            ),
            bodyMedium: TextStyle(
              color: AppColors.textDark, // Changed from textBody to textDark
            ),
            bodySmall: TextStyle(
              color: AppColors.textLight,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.mediumLightGreen),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightGreen),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.darkGreen, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.primary),
              foregroundColor: WidgetStateProperty.all(Colors.white),
              elevation: WidgetStateProperty.all(4),
              shadowColor: WidgetStateProperty.all(AppColors.darkPeriwinkleWithOpacity), // Fixed color constant
            ),
          ),
          // Add bottom sheet theme
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.transparent,
            constraints: BoxConstraints(
              maxHeight: double.infinity,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ),
        builder: (context, child) {
          SizeConfig.init(context);
          return child!;
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Add these new properties
  bool _networkChecked = false;
  bool _minimumTimeElapsed = false;
  final int _minimumSplashDuration = 5; // 5 seconds minimum
  final VersionService _versionService = VersionService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    _controller.forward();
    
    // Start both checks simultaneously
    _checkVersionAndNetwork();
  }

  Future<void> _checkVersionAndNetwork() async {
    await Future.wait([
      _checkVersion(),
      _checkNetworkAndNavigate(),
      Future.delayed(Duration(seconds: _minimumSplashDuration)),
    ]);

    if (mounted) {
      setState(() {
        _networkChecked = true;
        _minimumTimeElapsed = true;
        _tryNavigate();
      });
    }
  }

  Future<void> _checkVersion() async {
    try {
      final update = await _versionService.checkForUpdates();
      if (update != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (BuildContext dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.secondary,
                        ],
                      ).createShader(bounds);
                    },
                    child: const Icon(
                      Icons.system_update,
                      size: 50,
                      color: Colors.white, // This color will be masked by the gradient
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Update Available!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Current version:',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${update['currentVersion']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New version:',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${update['version']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${update['releaseNotes']}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => SystemNavigator.pop(),
                        child: const Text(
                          'Exit App',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final url = Uri.parse(update['url']);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                              SystemNavigator.pop();
                            }
                          },
                          child: const Text(
                            'Update Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Error checking version: $e\n$stack');
    }
  }

  Future<void> _checkNetworkAndNavigate() async {
    try {
      // Check network speed by downloading a small file
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse('https://www.google.com/favicon.ico'));
      stopwatch.stop();

      if (!mounted) return;

      // Calculate network speed
      final size = response.bodyBytes.length;
      final durationInSeconds = stopwatch.elapsedMilliseconds / 1000;
      final speedInKBps = (size / 1024) / durationInSeconds;

      debugPrint('Network speed: ${speedInKBps.toStringAsFixed(2)} KB/s');

      // Add additional delay for slow networks
      int additionalDelay = 0;
      if (speedInKBps < 50) { // Very slow
        additionalDelay = 2000;
      } else if (speedInKBps < 100) { // Slow
        additionalDelay = 1000;
      }

      await Future.delayed(Duration(milliseconds: additionalDelay));

      if (!mounted) return;
      setState(() {
        _networkChecked = true;
        _tryNavigate();
      });

    } catch (e) {
      debugPrint('Network check error: $e');
      // If network check fails, still proceed after minimum time
      if (mounted) {
        setState(() {
          _networkChecked = true;
          _tryNavigate();
        });
      }
    }
  }

  void _tryNavigate() {
    // Only navigate if both minimum time has elapsed and network check is complete
    if (_minimumTimeElapsed && _networkChecked) {
      _performNavigation();
    }
  }

  Future<void> _performNavigation() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        user != null ? '/home' : '/login',
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background Design
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        AppColors.lightBlue.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Main Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Image.asset(
                        'assets/images/splash.png',
                        height: 200, // Slightly larger since we removed other elements
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Bottom section with reduced spacing
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Yoga Ugam',
                        style: TextStyle(
                          fontSize: 36, // Larger size
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 5), // Reduced to 5px
                      const Text(
                        'Experience the transformation',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Version text
                      Text(
                        'v${AppConfig.currentVersion}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
