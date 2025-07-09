import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:async';
import '../models/yoga_models.dart';
import '../theme/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/points_model.dart';
import 'dart:math' show cos, pi, sin;
// Add this import for better time formatting
import 'package:flutter/services.dart';  // Add this for haptic feedback

const _kDialogTransitionDuration = Duration(milliseconds: 450);
const _kDialogElevation = 24.0;

class TrainingDetailPage extends StatefulWidget {
  final String title;
  final int duration;
  final List<YogaStep> steps;  // Add this field
  final VoidCallback onComplete;  // Add this field
  final Rect? sourceRect; // Add this field
  final GlobalKey? heroKey;

  const TrainingDetailPage({
    super.key,
    required this.title,
    required this.duration,
    required this.steps,
    required this.onComplete,
    this.sourceRect,
    this.heroKey,
  });

  static Future<void> navigate(
    BuildContext context, {
    required String title,
    required int duration,
    required List<YogaStep> steps,
    required VoidCallback onComplete,
    required GlobalKey heroKey,
    required Rect sourceRect,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => TrainingDetailPage(
          title: title,
          duration: duration,
          steps: steps,
          onComplete: onComplete,
          heroKey: heroKey,
          sourceRect: sourceRect,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final rectTween = RectTween(
            begin: sourceRect,
            end: Rect.fromLTWH(0, 0, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
          );

          final sizeTween = Tween<double>(begin: 0, end: 1);
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
          );

          return Stack(
            children: [
              // Background fade
              FadeTransition(
                opacity: fadeAnimation,
                child: Container(color: Theme.of(context).scaffoldBackgroundColor),
              ),
              // Main content animation
              AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  final rect = rectTween.evaluate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ));

                  final scale = sizeTween.evaluate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  ));

                  return Positioned.fromRect(
                    rect: rect!,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: child,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

class _TrainingDetailPageState extends State<TrainingDetailPage> with TickerProviderStateMixin {
  Timer? _timer;
  int _currentStepIndex = 0;
  int _remainingSeconds = 0;
  bool _isActive = false;
  bool _isLoading = true;
  String? _errorMessage;
  final _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  final _audioPlayer = AudioPlayer();
  bool _isCompleted = false;
  final _stepCompletePlayer = AudioPlayer();
  final _cheerPlayer = AudioPlayer();
  late AnimationController _timerAnimationController;
  late Animation<double> _timerAnimation;
  Map<String, dynamic> _todayProgress = {
    'todayPoints': 0,
    'targetPoints': 10,
    'progress': 0.0,
  };
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _motionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAllAnimations();
    
    if (widget.steps.isEmpty) {
      setState(() {
        _errorMessage = 'No steps available for this practice';
        _isLoading = false;
      });
      return;
    }

    // Sort steps by step number
    final sortedSteps = List<YogaStep>.from(widget.steps);
    sortedSteps.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
    widget.steps..clear()..addAll(sortedSteps);
    
    _loadTodayProgress();
    _initializeStep();
    _initializeAudio();
    
    // Show first pose preview immediately
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showPosePreview(() {
          if (mounted) _startTimer();
        });
      }
    });
  }

  void _initializeAllAnimations() {
    // Initialize slide controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );

    // Initialize motion controller with proper duration
    _motionController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInOutSine,
    ));

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _motionController,
      curve: Curves.easeInOutSine,
    ));

    // Initialize timer animation
    _timerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _timerAnimation = CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.easeInOut,
    );

    // Start repeating animations
    _motionController.repeat(reverse: true);
  }

  Future<void> _loadTodayProgress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final progress = await YogaPoints.getTodayProgress(user.uid);
        setState(() {
          _todayProgress = progress;
        });
      }
    } catch (e) {
      debugPrint('Error loading today\'s progress: $e');
    }
  }

  Future<void> _initializeAudio() async {
    try {
      debugPrint('Initializing audio players...');
      
      await _stepCompletePlayer.setReleaseMode(ReleaseMode.release);
      await _cheerPlayer.setReleaseMode(ReleaseMode.release);
      
      await _stepCompletePlayer.setSource(AssetSource('audio/b2.mp3'));
      await _cheerPlayer.setSource(AssetSource('audio/cheer.mp3'));
      
      await _stepCompletePlayer.setVolume(1.0);
      await _cheerPlayer.setVolume(1.0);

      debugPrint('Audio initialization complete');
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  void _playStepCompleteSound() async {
    try {
      debugPrint('Attempting to play step complete sound');
      if (_stepCompletePlayer.state == PlayerState.playing) {
        await _stepCompletePlayer.stop();
      }
      await _stepCompletePlayer.seek(Duration.zero);
      await _stepCompletePlayer.resume();
      debugPrint('Step complete sound played successfully');
    } catch (e) {
      debugPrint('Error playing step complete sound: $e');
    }
  }

  void _playCheerSound() async {
    try {
      debugPrint('Attempting to play cheer sound');
      if (_cheerPlayer.state == PlayerState.playing) {
        await _cheerPlayer.stop();
      }
      await _cheerPlayer.seek(Duration.zero);
      await _cheerPlayer.resume();
      debugPrint('Cheer sound played successfully');
    } catch (e) {
      debugPrint('Error playing cheer sound: $e');
    }
  }

  Future<void> _addPointsAndActivity() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
        
        // Check today's points first
        final todayProgress = await YogaPoints.getTodayProgress(user.uid);
        if (todayProgress['todayPoints'] >= 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You\'ve already earned maximum points (10) for today!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        const pointsToAdd = 1; // Add only 1 point per completion
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final date = DateTime.now();
        final dateString = DateTime(date.year, date.month, date.day).toIso8601String();
        final exactTime = date.toIso8601String();

        // Add to points_history
        await userRef.child('points_history/$timestamp').set({
          'activity': widget.title,
          'exactTime': exactTime,
          'points': pointsToAdd,
          'timestamp': dateString,
          'type': 'practice_completion'
        });

        // Add to activities
        await userRef.child('userdata/activities/$timestamp').set({
          'completed': true,
          'date': dateString,
          'points': pointsToAdd,
          'timestamp': exactTime,
          'title': widget.title
        });

        // Update total points
        await userRef.child('userdata/totalpoints').once().then((event) async {
          final currentPoints = (event.snapshot.value as int?) ?? 0;
          await userRef.child('userdata/totalpoints').set(currentPoints + pointsToAdd);
        });

        _confettiController.play();
        _playCheerSound();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Congratulations! You earned 1 point!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding points and activity: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _motionController.dispose();
    _slideController.dispose();
    _timerAnimationController.dispose();
    _confettiController.dispose();
    _stepCompletePlayer.dispose();
    _cheerPlayer.dispose();
    super.dispose();
  }

  void _initializeStep() {
    try {
      if (widget.steps.isEmpty) {
        throw Exception('No steps available');
      }
      
      final step = widget.steps[_currentStepIndex];
      
      // Parse duration properly
      final duration = step.duration.toLowerCase().trim();
      int seconds = 0;
      
      if (duration.contains('h')) {
        final hours = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        seconds = hours * 3600;
      } else if (duration.contains('m')) {
        final minutes = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        seconds = minutes * 60;
      } else if (duration.contains('s')) {
        seconds = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      } else {
        // Try to parse as pure number (assuming seconds)
        seconds = int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
      
      if (seconds <= 0) {
        throw Exception('Invalid duration: $duration');
      }
      
      setState(() {
        _remainingSeconds = seconds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize training: $e';
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) return;
    
    HapticFeedback.mediumImpact();
    setState(() => _isActive = true);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_remainingSeconds % 10 == 0) {
            // Haptic feedback every 10 seconds
            HapticFeedback.lightImpact();
          }
        } else {
          _moveToNextStep();
        }
      });
    });
  }

  void _playStepStartSound() async {
    try {
      if (_stepCompletePlayer.state == PlayerState.playing) {
        await _stepCompletePlayer.stop();
      }
      await _stepCompletePlayer.seek(Duration.zero);
      await _stepCompletePlayer.resume();
      debugPrint('Step start sound played successfully');
    } catch (e) {
      debugPrint('Error playing step start sound: $e');
    }
  }

  void _moveToNextStep() {
    _timer?.cancel();

    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        final nextStep = widget.steps[_currentStepIndex];
        _remainingSeconds = getDurationInSeconds(nextStep.duration);
        _isActive = false;
      });
      
      _showPosePreview(() {
        if (mounted) {
          _startTimer();
        }
      });
    } else {
      setState(() {
        _isActive = false;
        _isCompleted = true;
      });
      _showCompletionModal();
    }
  }

  void _showPosePreview(VoidCallback onComplete) {
    HapticFeedback.mediumImpact(); // Add haptic feedback
    _playStepStartSound();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => TweenAnimationBuilder(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.8, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: _buildPreviewDialog(context, onComplete),
          );
        },
      ),
    );

    // Auto-close preview after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (context.mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        onComplete();
      }
    });
  }

  Widget _buildPreviewDialog(BuildContext context, VoidCallback onComplete) {
    return SimpleDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Add timer at the top
              _buildCircularTimer(),
              const SizedBox(height: 16),
              Text(
                widget.steps[_currentStepIndex].pose1,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CachedNetworkImage(
                  imageUrl: widget.steps[_currentStepIndex].model,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onComplete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Start'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCompletionModal() {
    _playCheerSound();
    _confettiController.play();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // Background modal dialog
              Center(
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.8,
                    end: 1.0,
                  ).animate(curvedAnimation),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Practice Complete!',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You completed all ${widget.steps.length} poses',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            // Today's Progress Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Today's Progress",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${_todayProgress['todayPoints'] + 1}/${_todayProgress['targetPoints']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: (_todayProgress['todayPoints'] + 1) / _todayProgress['targetPoints'],
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  await _addPointsAndActivity(); // Add points
                                  if (mounted) {
                                    Navigator.of(context).pop(); // Close the modal dialog
                                    Navigator.of(context).pop(); // Dismiss the TrainingDetailPage
                                    widget.onComplete(); // Trigger completion callback
                                  }
                                } catch (e) {
                                  debugPrint("Awesome button error: $e");
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Awesome!',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Confetti overlay on top
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.directional,
                  blastDirection: pi / 2,
                  maxBlastForce: 7,
                  minBlastForce: 3,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.3,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isActive = false);
  }

  void _previousStep() {
    if (_currentStepIndex <= 0) return;

    _timer?.cancel();
    setState(() {
      _currentStepIndex--;
      final prevStep = widget.steps[_currentStepIndex];
      _remainingSeconds = getDurationInSeconds(prevStep.duration);
      _isActive = false;
    });
    
    _showPosePreview(() {
      if (mounted) {
        _startTimer();
      }
    });
  }

  void _nextStep() {
    if (_currentStepIndex >= widget.steps.length - 1) return;

    _timer?.cancel();
    setState(() {
      _currentStepIndex++;
      final nextStep = widget.steps[_currentStepIndex];
      _remainingSeconds = getDurationInSeconds(nextStep.duration);
      _isActive = false;
    });
    
    _showPosePreview(() {
      if (mounted) {
        _startTimer();
      }
    });
  }

  void _showStopConfirmation() {
    if (!mounted) return;
    
    _timer?.cancel();  // Pause the timer while showing dialog
    
    showDialog<bool>(
      context: context,
      barrierDismissible: false,  // Prevent dismissing by tapping outside
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Stop Training?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text('Are you sure you want to stop this training session?'),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                    if (_isActive) _startTimer();  // Resume timer if it was active
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue Training',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Stop Training',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).then((shouldStop) {
      if (shouldStop == true && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pop();  // Pop only after the frame is complete
        });
      }
    });
  }

  Widget _buildPoseImage(YogaStep currentStep) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'pose_${currentStep.pose1}',
              child: CachedNetworkImage(
                imageUrl: currentStep.model,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection(int minutes, int seconds) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _timerAnimation,
            child: Text(
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.height * 0.06,
                fontWeight: FontWeight.w300,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                onPressed: _currentStepIndex > 0 ? _previousStep : null,
              ),
              _buildPlayPauseButton(),
              _buildControlButton(
                icon: Icons.skip_next,
                onPressed: _currentStepIndex < widget.steps.length - 1 ? _nextStep : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'No exercises available',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null || widget.steps.isEmpty) {
      return _buildErrorScreen();
    }

    final currentStep = widget.steps[_currentStepIndex];

    return WillPopScope(  // Use WillPopScope instead of PopScope for better control
      onWillPop: () async {
        _showStopConfirmation();
        return false;  // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: _buildMainContent(context, currentStep),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed != null ? AppColors.secondary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              icon,
              size: 28,
              color: onPressed != null ? AppColors.secondary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: _isActive ? 2 : 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton.large(
              onPressed: _isActive ? _pauseTimer : _startTimer,
              backgroundColor: _isActive ? AppColors.secondary : AppColors.primary,
              elevation: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: RotationTransition(
                      turns: animation,
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey<bool>(_isActive),
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return remainingSeconds > 0 ? '${minutes}m ${remainingSeconds}s' : '${minutes}m';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final remainingSeconds = seconds % 60;
      String result = '${hours}h';
      if (minutes > 0) result += ' ${minutes}m';
      if (remainingSeconds > 0) result += ' ${remainingSeconds}s';
      return result;
    }
  }

  Widget _buildTimerDisplay() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isActive ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.secondary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              _formatDuration(_remainingSeconds),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0, end: (_currentStepIndex + 1) / widget.steps.length),
      builder: (context, value, child) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: MediaQuery.of(context).size.width * value,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  int getDurationInSeconds(String duration) {
    final dur = duration.toLowerCase().trim();
    if (dur.contains('h')) {
      final hours = int.tryParse(dur.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return hours * 3600;
    } else if (dur.contains('m')) {
      final minutes = int.tryParse(dur.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return minutes * 60;
    } else if (dur.contains('s')) {
      return int.tryParse(dur.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return int.tryParse(dur.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  Widget _buildMainContent(BuildContext context, YogaStep currentStep) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360 || size.height < 600;
    final padding = isSmallScreen ? 12.0 : 20.0;

    return Column(
      children: [
        // Minimal header - removed timer section
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.white.withOpacity(0.8),
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding/2),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _showStopConfirmation(),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _showStopConfirmation(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Pose image
        Expanded(
          child: Container(
            margin: EdgeInsets.all(padding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'pose_${currentStep.pose1}',
                    child: CachedNetworkImage(
                      imageUrl: currentStep.model,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom controls with timer
        Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress section with timer
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    // Left side - Progress info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStep.pose1,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (_currentStepIndex + 1) / widget.steps.length,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Step ${_currentStepIndex + 1} of ${widget.steps.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    // Timer positioned in top right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCircularTimer(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _currentStepIndex > 0 ? _previousStep : null,
                      icon: const Icon(Icons.skip_previous),
                      color: AppColors.secondary,
                    ),
                    FloatingActionButton(
                      onPressed: _isActive ? _pauseTimer : _startTimer,
                      backgroundColor: AppColors.secondary,
                      child: Icon(_isActive ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(
                      onPressed: _currentStepIndex < widget.steps.length - 1 ? _nextStep : null,
                      icon: const Icon(Icons.skip_next),
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerText() {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Text(
      '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStepIndex + 1} of ${widget.steps.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              Text(
                '${((_currentStepIndex + 1) / widget.steps.length * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentStepIndex + 1) / widget.steps.length,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.skip_previous,
          onPressed: _currentStepIndex > 0 ? _previousStep : null,
        ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _isActive 
                ? [AppColors.secondary, AppColors.primary]
                : [AppColors.primary, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: _isActive ? 2 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.large(
            onPressed: _isActive ? _pauseTimer : _startTimer,
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Icon(
              _isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 48,
            ),
          ),
        ),
        _buildControlButton(
          icon: Icons.skip_next,
          onPressed: _currentStepIndex < widget.steps.length - 1 ? _nextStep : null,
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCircularTimer() {
    final hours = _remainingSeconds ~/ 3600;
    final minutes = (_remainingSeconds % 3600) ~/ 60;
    final seconds = _remainingSeconds % 60;

    return Text(
      hours > 0 
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.secondary,  // Changed to secondary color
        fontFamily: 'monospace',
      ),
    );
  }

  // Update the icon getter to always return yoga icon
  IconData _getPracticeIcon(String practiceName) {
    return Icons.self_improvement_rounded;  // Always return yoga icon
  }
}
