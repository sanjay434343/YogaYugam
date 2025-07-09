import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' show Random, pi, cos, sin;
import 'dart:ui'; // Add this for ImageFilter
import 'package:flutter/services.dart'; // Add this import at the top
import 'dart:async'; // Add this import for Timer
// Add this import for animations
import '../theme/colors.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override 
  State<LoginPage> createState() => _LoginPageState();
}

// Change from SingleTickerProviderStateMixin to TickerProviderStateMixin
class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final Random _random = Random();
  final List<ParticleModel> particles = [];
  
  bool _isLoading = false;
  final bool _isHoveringSignIn = false;
  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _animation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _formOpacityAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateParticles();
    
    // Initialize fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    );

    _cardSlideAnimation = Tween<double>(
      begin: 100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCirc),
    ));

    _cardFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _formOpacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    ));

    _animationController.forward();
    _cardAnimationController.forward();
  }

  void _generateParticles() {
    for (var i = 0; i < 20; i++) {
      particles.add(ParticleModel(_random));
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
     try {
        final String? uid = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (uid != null) {
          // Use pushAndRemoveUntil to clear the navigation stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login failed. Please check your credentials.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSignUpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 1.0, end: 0.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * value),
              child: Opacity(
                opacity: 1 - value,
                child: child,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Updated Header with margins
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6), // Add 6px gap
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.secondary,
                          AppColors.secondary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(40),
                        bottom: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_circle_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Create Your Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get Started with YOGAM',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sign up on our website to unlock the full potential of your yoga journey:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Benefits list
                      ...[ 
                        'Access premium yoga courses and tutorials',
                        'Track your progress and achievements',
                        'Get regular app updates and new features',
                        'Join our growing yoga community',
                        'Seamlessly sync across devices'
                      ].map((benefit) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                benefit,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          // Maybe Later button
                          Expanded(
                            child: SizedBox(
                              height: 50, // Add fixed height
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.red.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Maybe Later',
                                  style: TextStyle(
                                    color: Colors.red[400],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Sign Up button
                          Expanded(
                            child: SizedBox(
                              height: 50, // Add fixed height
                              child: _buildGradientButton(
                                onPressed: () async {
                                  final url = Uri.parse('https://yoogam.netlify.app/signup');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Sign Up Now',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: onPressed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Particle background
            CustomPaint(
              painter: ParticlesPainter(particles, AppColors.secondary),
              child: Container(),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    // Welcome text section with enhanced animations
                    AnimatedBuilder(
                      animation: _cardAnimationController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - _cardFadeAnimation.value)),
                          child: Opacity(
                            opacity: _cardFadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Continue Your ',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    letterSpacing: 0.5,
                                    height: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Journey',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    letterSpacing: 0.5,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your Own Gateway to Awakening',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40), // Adjusted spacing after removing text
                    
                    // Login form
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildModernFormField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 16),
                          _buildModernFormField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 24),
                          // Replace regular button with SwipeableButton
                          SwipeableButton(
                            onSwipeComplete: _handleLogin,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 16),
                          _buildSignUpLink(),
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
  }

  Widget _buildAnimatedLogo() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(_animation),
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon with glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.self_improvement,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // App name with reflection effect
              Stack(
                children: [
                  // Reflection
                  Text(
                    'YOGAM',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                  // Main text
                  const Text(
                    'YOGAM',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
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

  // Update _buildLoginForm method
  Widget _buildLoginForm() {
    return FadeTransition(
      opacity: _formOpacityAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModernFormField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 16),
            _buildModernFormField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 24),
            _buildModernButton(),
            const SizedBox(height: 20),
            _buildSignUpLink(),
          ],
        ),
      ),
    );
  }

  // Add new modern form field
  Widget _buildModernFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.secondary),
          prefixIcon: Icon(icon, color: AppColors.secondary),
          filled: true,
          fillColor: AppColors.secondary.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.secondary,
              width: 2,
            ),
          ),
          errorStyle: const TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Add modern button with hover effect
  Widget _buildModernButton() {
    return SwipeableButton(
      isLoading: _isLoading,
      onSwipeComplete: _handleLogin,
    );
  }

  // Add modern sign up link
  Widget _buildSignUpLink() {
    return TextButton(
      onPressed: _showSignUpDialog,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Text(
            'Sign Up',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Icon(
            Icons.arrow_forward,
            size: 16,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    _cardAnimationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

class ParticleModel {
  double x;
  double y;
  double speed;
  double theta;

  ParticleModel(Random random)
      : x = random.nextDouble(),
        y = random.nextDouble(),
        speed = 0.2 + random.nextDouble() * 0.8,
        theta = random.nextDouble() * 2 * pi;

  void update() {
    // Use math functions directly since they're now imported
    x += speed * 0.001 * cos(theta);
    y += speed * 0.001 * sin(theta);

    if (x < 0 || x > 1) theta = pi - theta;
    if (y < 0 || y > 1) theta = -theta;
  }
}

class ParticlesPainter extends CustomPainter {
  final List<ParticleModel> particles;
  final Color color;

  ParticlesPainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        2,
        paint,
      );
      particle.update();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class GlowingProgressIndicator extends StatelessWidget {
  const GlowingProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 2,
      ),
    );
  }
}

class ModernParticlesPainter extends CustomPainter {
  final List<ParticleModel> particles;
  final Color color;
  final double animationValue;

  ModernParticlesPainter(this.particles, this.color, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (var particle in particles) {
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        2,
        paint,
      );
      particle.update();
    }

    // Draw connecting lines
    for (var i = 0; i < particles.length; i++) {
      for (var j = i + 1; j < particles.length; j++) {
        final p1 = particles[i];
        final p2 = particles[j];
        final distance = (Offset(p1.x, p1.y) - Offset(p2.x, p2.y)).distance;
        if (distance < 0.1) {
          final opacity = (1 - distance / 0.1) * 0.1;
          paint.color = color.withOpacity(opacity);
          canvas.drawLine(
            Offset(p1.x * size.width, p1.y * size.height),
            Offset(p2.x * size.width, p2.y * size.height),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class SwipeableButton extends StatefulWidget {
  final VoidCallback onSwipeComplete;
  final bool isLoading;

  const SwipeableButton({
    super.key,
    required this.onSwipeComplete,
    this.isLoading = false,
  });

  @override
  State<SwipeableButton> createState() => _SwipeableButtonState();
}

class _SwipeableButtonState extends State<SwipeableButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragValue = 0.0;
  bool _isDragging = false;

  // Add these new properties for haptic feedback control
  final int _hapticSteps = 5; // Number of vibration steps
  final double _lastHapticThreshold = 0.0;
  final double _hapticThresholdInterval = 0.2; // 20% intervals

  // Add these new properties
  final List<Color> _trailColors = [
    Colors.white.withOpacity(0.3),
    Colors.white.withOpacity(0.2),
    Colors.white.withOpacity(0.1),
  ];
  final _trailCount = 3;

  // Add this property to control continuous vibration
  Timer? _vibrationTimer;

  void _startContinuousVibration() {
    // Cancel any existing timer
    _vibrationTimer?.cancel();
    
    // Create new timer that vibrates every 50ms
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_dragValue < 0.3) {
        HapticFeedback.selectionClick();
      } else if (_dragValue < 0.5) {
        HapticFeedback.lightImpact();
      } else if (_dragValue < 0.7) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stopContinuousVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  void _onDragStart(DragStartDetails details) {
    HapticFeedback.mediumImpact();
    _startContinuousVibration();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      final newValue = (_dragValue + details.delta.dx / context.size!.width)
          .clamp(0.0, 1.0);
      _dragValue = newValue;
      _isDragging = true;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _stopContinuousVibration();
    
    if (_dragValue > 0.7) {
      _controller.forward();
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
      });
      widget.onSwipeComplete();
    } else {
      _controller.animateTo(0.0);
      HapticFeedback.lightImpact();
    }
    setState(() {
      _dragValue = 0.0;
      _isDragging = false;
    });
  }

  @override
  void dispose() {
    _stopContinuousVibration();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = MediaQuery.of(context).size.width - 48; // Reduced width
    const thumbWidth = 60.0; // Smaller thumb
    final maxDragDistance = buttonWidth - thumbWidth - 8; // Account for padding

    return Container(
      height: 56,
      width: buttonWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.secondary.withOpacity(0.8),
            AppColors.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background with animated arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated arrow trail
              ...List.generate(_trailCount, (index) {
                return Transform.translate(
                  offset: Offset(-20.0 * (1 - _dragValue) * (_trailCount - index), 0),
                  child: Icon(
                    Icons.arrow_forward,
                    color: _trailColors[index],
                    size: 20,
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                'Slide to Sign In',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6 + (0.4 * _dragValue)),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          // Animated thumb with trail effect
          Padding(
            padding: const EdgeInsets.all(4),
            child: GestureDetector(
              onHorizontalDragStart: widget.isLoading ? null : _onDragStart, // Add this line
              onHorizontalDragUpdate: widget.isLoading ? null : _onDragUpdate,
              onHorizontalDragEnd: widget.isLoading ? null : _onDragEnd,
              child: Stack(
                children: [
                  // Thumb trails
                  ...List.generate(3, (index) {
                    return Transform.translate(
                      offset: Offset(_dragValue * maxDragDistance - (index * 8 * _dragValue), 0),
                      child: Opacity(
                        opacity: 0.3 - (index * 0.1),
                        child: Container(
                          width: thumbWidth,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }).reversed,
                  // Main thumb
                  Transform.translate(
                    offset: Offset(_dragValue * maxDragDistance, 0),
                    child: Container(
                      width: thumbWidth,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward,
                                color: AppColors.secondary,
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
