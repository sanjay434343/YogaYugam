import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; // Fixed import
import 'package:intl/intl.dart';
import 'package:async/async.dart';  // Add this import
// ensure http is imported for network check
import '../services/local_storage_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String courseId;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.courseId,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

// Change SingleTickerProviderStateMixin to TickerProviderStateMixin
class _VideoPlayerScreenState extends State<VideoPlayerScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {  // Add WidgetsBindingObserver mixin
  // Change from late to nullable
  VideoPlayerController? _videoPlayerController;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isBuffering = false;

  // Add new properties
  bool _showControls = true;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;
  bool _isFullScreen = false;

  // Add new properties for timeline
  List<Map<String, dynamic>> _timelineItems = [];
  int _currentVideoIndex = 0;
  bool _isLoadingTimeline = true;
  bool _isUserInteracting = false;  // Add this property

  // Add this property
  late SharedPreferences _prefs;

  // Add new properties for comments
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  String _currentChapterId = ''; // Add this line

  // Add new properties at the top of the class
  final bool _isAdjustingPosition = false;
  final bool _isAdjustingVolume = false;
  final double _dragStartPosition = 0;
  final double _currentVolume = 1.0;
  final double _currentBrightness = 1.0;

  // Update the controls visibility timer duration
  static const _controlsHideDelay = Duration(seconds: 3);
  static const _controlsFadeDuration = Duration(milliseconds: 300);

  // Add all animation controllers at the top
  late AnimationController _fadeController;
  late AnimationController _controlsController;
  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScaleAnimation;
  
  // Add new properties for pinch-to-zoom
  final double _scale = 1.0;
  double _previousScale = 1.0;

  // Add these zoom-related properties
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  Offset _position = Offset.zero;

  // Add these properties for better zoom control
  final double _minScale = 1.0;
  final double _maxScale = 3.0;

  // Add these properties
  CancelableOperation? _loadCommentsOperation;
  CancelableOperation? _fetchTimelineOperation;

  // Add storage service
  late LocalStorageService _storageService;

  // Add these new properties for comment animation
  final GlobalKey _inputFieldKey = GlobalKey();
  final GlobalKey _commentsListKey = GlobalKey();
  OverlayEntry? _flyingTextOverlay;

  // Add this property at the top of the class
  DateTime _lastPositionSave = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initPreferences();
    WidgetsBinding.instance.addObserver(this);
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    // Initialize player directly without verification
    _initializePlayer();
    
    // Initialize other components
    _videoPlayerController?.addListener(_videoPlayerListener);
    _tabController = TabController(length: 2, vsync: this);
    _loadComments();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize all animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: _controlsFadeDuration,
    );
    
    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Setup animations
    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _buttonScaleController,
      curve: Curves.easeInOut,
    ));

    // Ensure status bar is visible and colored
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primary,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    // Add this line to fetch timeline data
    _fetchTimelineData();

    // Add this line to force portrait mode on init
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = LocalStorageService(prefs);
    
    // Initialize video player directly
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(''),
    );
    try {
      await _videoPlayerController?.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing empty player: $e');
    }
  }

  // Add this method
  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    // Restore last video index
    final lastIndex = _prefs.getInt('${widget.courseId}_last_video_index') ?? 0;
    if (mounted) {
      setState(() {
        _currentVideoIndex = lastIndex;
      });
    }
  }

  // Update the dispose method
  @override
  void dispose() {
    // Add this before calling super.dispose()
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // Save final position before disposing
    _saveCurrentPosition();
    // First, remove all listeners and cancel timers
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;

    // Cancel any ongoing operations
    _loadCommentsOperation?.cancel();
    _fetchTimelineOperation?.cancel();

    // Dispose controllers in a safe way
    _disposeControllers();

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  // Add new method for safer controller disposal
  Future<void> _disposeControllers() async {
    try {
      await _videoPlayerController?.pause();
      await _videoPlayerController?.dispose();
      _videoPlayerController = null;

      _fadeController.dispose();
      _controlsController.dispose();
      _buttonScaleController.dispose();
      _tabController.dispose();
      _commentController.dispose();
    } catch (e) {
      debugPrint('Error disposing controllers: $e');
    }
  }

  // Add this method to properly dispose current controller
  Future<void> _disposeCurrentController() async {
    try {
      if (_videoPlayerController != null) {
        _videoPlayerController?.removeListener(_videoPlayerListener);
        await _videoPlayerController?.pause();
        await _videoPlayerController?.dispose();
        _videoPlayerController = null;
      }
    } catch (e) {
      debugPrint('Error disposing controller: $e');
    }
  }

  // Update the _videoPlayerListener method
  void _videoPlayerListener() {
    if (!mounted || _videoPlayerController == null) return;
    
    try {
      // Save position periodically (every 5 seconds)
      if (_videoPlayerController!.value.isPlaying && 
          DateTime.now().difference(_lastPositionSave) > const Duration(seconds: 5)) {
        _saveCurrentPosition();
        _lastPositionSave = DateTime.now();
      }

      if (_videoPlayerController?.value.hasError ?? false) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Video playback error occurred';
          });
        }
        return;
      }

      final isCurrentlyBuffering = _videoPlayerController?.value.isBuffering ?? false;
      if (isCurrentlyBuffering != _isBuffering && mounted) {
        setState(() {
          _isBuffering = isCurrentlyBuffering;
        });
      }

      // Auto-hide controls after video starts playing
      if (_videoPlayerController?.value.isPlaying ?? false) {
        _resetHideControlsTimer();
      }

      // Check if video ended
      if (mounted && 
          _videoPlayerController?.value.position != null &&
          _videoPlayerController?.value.duration != null &&
          _videoPlayerController!.value.position >= _videoPlayerController!.value.duration) {
        _playNextVideo();
      }

      // Save position periodically while playing
      if (mounted && 
          (_videoPlayerController?.value.isPlaying ?? false) && 
          _timelineItems.isNotEmpty) {
        final currentChapterId = _timelineItems[_currentVideoIndex]['id'] as String? ?? '';
        _saveVideoPosition(currentChapterId);
      }

      // Save progress periodically
      if (_videoPlayerController?.value.position != null && 
          _videoPlayerController?.value.duration != null) {
        final position = _videoPlayerController!.value.position;
        final duration = _videoPlayerController!.value.duration;
        final progress = position.inMilliseconds / duration.inMilliseconds;
        
        // Get chapter data from timeline
        final currentChapter = _timelineItems.firstWhere(
          (item) => item['id'] == _currentChapterId,
          orElse: () => <String, dynamic>{},
        );

        _storageService.saveLastViewedVideo(
          courseId: widget.courseId,
          chapterId: _currentChapterId,
          title: widget.title,
          thumbnailUrl: currentChapter['thumbnail'] ?? '',
          videoUrl: currentChapter['src'] ?? '',
          progress: progress,
        );
      }
    } catch (e) {
      debugPrint('Error in video player listener: $e');
    }
  }

Future<Map<String, Map<String, dynamic>>> _fetchVideoData(String courseId, String chapterId) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    debugPrint('Fetching course: $courseId, chapter: $chapterId');

    final DatabaseReference coursesRef = FirebaseDatabase.instance
        .ref()
        .child('courses')
        .child(courseId);

    final DataSnapshot snapshot = await coursesRef.get();
    
    if (!snapshot.exists) {
      throw Exception('Course not found');
    }

    final courseData = snapshot.value as Map<dynamic, dynamic>?;
    if (courseData == null) {
      throw Exception('Course data is null');
    }

    final content = courseData['content'] as Map<dynamic, dynamic>?;
    if (content == null) {
      throw Exception('Course content is null');
    }
    
    // Fix the null check issue by using null-safe operators
    final chapter = content[chapterId] as Map<dynamic, dynamic>?;
    if (chapter == null || !chapter.containsKey('src') || !chapter.containsKey('title')) {
      throw Exception('Invalid chapter structure');
    }

    // Convert chapter data to Map<String, dynamic>
    final chapterData = Map<String, dynamic>.from(chapter);
    
    final src = chapterData['src'] as String?;
    final title = chapterData['title'] as String?;

    if (src == null || title == null) {
      throw Exception('Missing required chapter data');
    }

    debugPrint('Loading video: $title, URL: $src');

    return {
      'currentChapter': chapterData, // include alternate quality keys if any
      'courseInfo': {
        'name': courseData['name'] as String? ?? 'Untitled Course',
        'description': courseData['description'] as String? ?? 'No description',
        'duration': courseData['duration'] as String? ?? '0:00',
      }
    };
  } catch (e) {
    debugPrint('Error in _fetchVideoData: $e');
    rethrow;
  }
}

  Future<void> _fetchVideoUrlAndInitializePlayer() async {
    if (!mounted) return; // Add this check
    setState(() {
      _isBuffering = true;
      _errorMessage = null;
    });

    try {
      final videoData = await _fetchVideoData(widget.courseId, 'ch1');
      String fetchedVideoUrl = videoData['currentChapter']?['src'];


      if (_videoPlayerController != null) {
        await _videoPlayerController!.dispose();
      }

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(fetchedVideoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoPlayerController!.initialize();
      debugPrint('Video player initialized successfully');

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });
        await _videoPlayerController!.play();
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading video: ${e.toString()}';
          _isBuffering = false;
        });
      }
    }
  }

  String _getDetailedErrorMessage(dynamic error) {
    if (error is PlatformException) {
      if (error.code == 'VideoError') {
        return 'Video playback error occurred';
      }
    }

    final errorStr = error.toString().toLowerCase();
    debugPrint('Detailed error: $errorStr');

    if (errorStr.contains('unrecognizedinputformatexception')) {
      return 'Video format not supported. Please try a different format.';
    }
    if (errorStr.contains('permission') || errorStr.contains('access')) {
      return 'Unable to access video. Please check URL and permissions.';
    }
    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'Video not found. Please check if the URL is correct.';
    }
    if (errorStr.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    if (errorStr.contains('exoplaybackexception')) {
      return 'Playback error. Please try a different video.';
    }
    return 'Error playing video: $error';
  }

  void _showChaptersMenu() async {
    try {
      final courseRef = FirebaseDatabase.instance
          .ref()
          .child('courses')
          .child(widget.courseId);
      
      final snapshot = await courseRef.get();

      if (!snapshot.exists) {
        throw Exception('Course not found');
      }

      final courseData = snapshot.value as Map<dynamic, dynamic>;
      final content = courseData['content'] as Map<dynamic, dynamic>;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseData['name'] ?? 'Course Content',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              Text(
                courseData['duration'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: content.length,
                  itemBuilder: (context, index) {
                    // Fix the null check issue
                    final chapterKey = content.keys.elementAt(index);
                    final chapter = content[chapterKey] as Map<dynamic, dynamic>? ?? {};
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(chapter['title'] ?? ''),
                      onTap: () async {
                        Navigator.pop(context);
                        if (chapter['src'] != null) {
                          await _loadVideo(chapterKey, chapter['src']);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing chapters menu: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load chapters';
        });
      }
    }
  }

  Future<void> _loadVideo(String chapterId, String src) async {
    if (!mounted || src.isEmpty) return;

    setState(() {
      _isBuffering = true;
      _errorMessage = null;
      _currentChapterId = chapterId;
    });

    try {
      // First dispose existing controller
      await _disposeCurrentController();

      // Create and initialize new controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(src),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Wait for initialization
      await controller.initialize();
      
      if (!mounted) {
        await controller.dispose();
        return;
      }

      // Update state with new controller
      setState(() {
        _videoPlayerController = controller;
        _isInitialized = true;
        _isBuffering = false;
      });

      // Add listener and start playing
      _videoPlayerController?.addListener(_videoPlayerListener);
      await _videoPlayerController?.play();

      // Update timeline index
      final selectedIndex = _timelineItems.indexWhere((item) => item['id'] == chapterId);
      if (selectedIndex != -1 && mounted) {
        setState(() {
          _currentVideoIndex = selectedIndex;
        });
        _saveVideoIndex();
      }

      // Load comments after video is initialized
      if (mounted) {
        await _loadComments();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getDetailedErrorMessage(e);
          _isBuffering = false;
        });
      }
    }
  }

  // Add this method to save position
  void _saveVideoPosition(String chapterId) {
    if (_videoPlayerController?.value.position != null) {
      _prefs.setInt(
        '${widget.courseId}_video_${chapterId}_position',
        _videoPlayerController!.value.position.inMilliseconds,
      );
    }
  }

  // Add this new method to save current video index
  void _saveVideoIndex() {
    _prefs.setInt('${widget.courseId}_last_video_index', _currentVideoIndex);
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 60,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _fetchVideoUrlAndInitializePlayer,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          _isBuffering ? 'Buffering...' : 'Loading video...',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

// Update the build method for better player controls and modern UI
Widget _buildVideoPlayer() {
  if (_videoPlayerController == null) {
    return const Center(child: CircularProgressIndicator());
  }

  final videoRatio = _videoPlayerController?.value.aspectRatio ?? 16/9;
  
  return GestureDetector(
    onTap: _toggleControls,
    behavior: HitTestBehavior.opaque,
    onDoubleTap: () {
      _togglePlay();
      _showControls = true;
      _resetHideControlsTimer();
    },
    onLongPress: _showVideoOptions,
    onScaleStart: _handleScaleStart,
    onScaleUpdate: _handleScaleUpdate,
    onScaleEnd: _handleScaleEnd,
    child: Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video container with transform
          Center(
            child: Transform(
              transform: Matrix4.identity()
                ..translate(_position.dx, _position.dy)
                ..scale(_currentScale),
              alignment: Alignment.center,
              child: AspectRatio(
                aspectRatio: videoRatio,
                child: _videoPlayerController != null 
                    ? VideoPlayer(_videoPlayerController!)
                    : Container(color: Colors.black),
              ),
            ),
          ),
          
          // Gradient overlays for better text readability
          if (_showControls) ...[
            // Top gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Play/Pause overlay with animation
          if (!_showControls)
            AnimatedOpacity(
              opacity: _videoPlayerController?.value.isPlaying ?? false ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: IconButton(
                  iconSize: 50,
                  icon: Icon(
                    _videoPlayerController?.value.isPlaying ?? false 
                        ? Icons.pause 
                        : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                ),
              ),
            ),

          // Controls overlay
          if (_showControls)
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildModernTopBar(),
                    _buildModernBottomControls(),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildModernTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Only show title, no back button
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Controls on right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed control with modern design
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
              onPressed: _toggleFullScreen,
            ),
          ],
        ),
      ],
    );
  }

Widget _buildModernBottomControls() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Progress bar with modern design
      _buildModernProgressBar(),
      const SizedBox(height: 8),
      // Single play/pause button
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            _videoPlayerController?.value.isPlaying ?? false
                ? Icons.pause
                : Icons.play_arrow,
            color: Colors.white,
            size: 36,
          ),
          onPressed: _togglePlay,
        ),
      ),
    ],
  );
}

Widget _buildModernProgressBar() {
  return Column(
    children: [
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 6,
          ),
          overlayShape: const RoundSliderOverlayShape(
            overlayRadius: 12,
          ),
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: Colors.white24,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withOpacity(0.3),
        ),
        child: Slider(
          value: _videoPlayerController?.value.position.inSeconds.toDouble() ?? 0,
          max: _videoPlayerController?.value.duration.inSeconds.toDouble() ?? 0,
          onChanged: (value) {
            _videoPlayerController?.seekTo(Duration(seconds: value.toInt()));
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_videoPlayerController?.value.position ?? Duration.zero),
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              _formatDuration(_videoPlayerController?.value.duration ?? Duration.zero),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ],
  );
}

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showControls = true; // Always show controls when toggling fullscreen
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    
    _resetHideControlsTimer();
  }

  void _setPlaybackSpeed(double speed) {
    _videoPlayerController?.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  void _seekRelative(int seconds) {
    final position = _videoPlayerController?.value.position;
    if (position != null) {
      _videoPlayerController?.seekTo(
        position + Duration(seconds: seconds),
      );
    }
  }

  void _togglePlay() {
    setState(() {
      if (_videoPlayerController?.value.isPlaying ?? false) {
        _videoPlayerController?.pause();
      } else {
        _videoPlayerController?.play();
      }
    });
  }

  // Update _toggleControls method to use animations
  void _toggleControls() {
    if (!mounted) return;

    if (_showControls) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() => _showControls = false);
        }
      });
    } else {
      setState(() => _showControls = true);
      _fadeController.forward();
      _resetHideControlsTimer();
    }
  }

  // Update the resetHideControlsTimer method
  void _resetHideControlsTimer() {
    if (!mounted) return;
    
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;

    if (_showControls && (_videoPlayerController?.value.isPlaying ?? false)) {
      _hideControlsTimer = Timer(_controlsHideDelay, () {
        if (!mounted) return;
        if (!_isUserInteracting) {
          _fadeController.reverse().then((_) {
            if (mounted) {
              setState(() => _showControls = false);
            }
          });
        }
      });
    }
  }

  Future<void> _fetchTimelineData() async {
    await _fetchTimelineOperation?.cancel();
    
    _fetchTimelineOperation = CancelableOperation<void>.fromFuture(Future(() async {
      try {
        setState(() => _isLoadingTimeline = true);

        final courseRef = FirebaseDatabase.instance
            .ref()
            .child('courses')
            .child(widget.courseId)
            .child('content');
        
        final snapshot = await courseRef.get();
        
        if (!snapshot.exists) {
          throw Exception('No content found');
        }

        final content = Map<String, dynamic>.from(snapshot.value as Map);
        List<Map<String, dynamic>> timeline = [];

        content.forEach((key, value) {
          if (value is Map) {
            final data = Map<String, dynamic>.from(value);
            timeline.add({
              'id': key,
              'sno': data['sno'] ?? 999,
              'title': data['title'] ?? 'Untitled',
              'duration': data['duration'] ?? '0:00',
              'src': data['src'] ?? '',
              'isCompleted': false,
            });
          }
        });

        timeline.sort((a, b) => (a['sno'] as num).compareTo(b['sno'] as num));

        if (mounted) {
          setState(() {
            _timelineItems = timeline;
            _isLoadingTimeline = false;
            
            if (timeline.isNotEmpty) {
              final videoToLoad = timeline[0]; // Load first video by default
              _loadVideo(videoToLoad['id'], videoToLoad['src']);
            }
          });
        }
      } catch (e) {
        debugPrint('Error fetching timeline: $e');
        if (mounted) {
          setState(() => _isLoadingTimeline = false);
        }
      }
    }));

    await _fetchTimelineOperation?.value;
  }

  void _playNextVideo() {
    if (_timelineItems.isEmpty) return;
    
    final nextIndex = _currentVideoIndex + 1;
    if (nextIndex < _timelineItems.length) {
      final nextVideo = _timelineItems[nextIndex];
      _loadVideo(nextVideo['id'], nextVideo['src']).then((_) {
        setState(() {
          _currentVideoIndex = nextIndex;
        });
        _saveVideoIndex();
      });
    } else {
      // Show completion dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('You have completed all lessons in this course.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadVideo(_timelineItems[0]['id'], _timelineItems[0]['src']);
                setState(() => _currentVideoIndex = 0);
              },
              child: const Text('Restart Course'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildVideoContent() {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isInitialized || _isBuffering || _videoPlayerController == null) {
      return _buildLoadingWidget();
    }

    final videoRatio = _videoPlayerController?.value.aspectRatio ?? 16/9;
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    // Calculate video dimensions
    double videoWidth;
    double videoHeight;
    
    if (isLandscape) {
      videoHeight = screenSize.height;
      videoWidth = videoHeight * videoRatio;
      if (videoWidth > screenSize.width) {
        videoWidth = screenSize.width;
        videoHeight = videoWidth / videoRatio;
      }
    } else {
      videoWidth = screenSize.width;
      videoHeight = videoWidth / videoRatio;
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: videoWidth,
          height: videoHeight,
          child: _buildVideoPlayer(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return PopScope(
      canPop: !_isFullScreen && !isLandscape,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          if (_isFullScreen || isLandscape) {
            await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
            setState(() => _isFullScreen = false);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Center video content with flexible space
              Expanded(
                flex: isLandscape ? 1 : 2,  // Give more weight in landscape
                child: Center(child: _buildVideoContent()),
              ),
              // Bottom section takes remaining space in portrait
              if (!_isFullScreen && !isLandscape)
                Expanded(
                  flex: 3,  // Give more space to content section
                  child: Container(
                    color: Colors.white,
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: AppColors.primary,
                            tabs: const [
                              Tab(text: 'Lessons'),
                              Tab(text: 'Comments'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildTimelineTabNew(),
                                _buildCommentsTabNew(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// Add this new method 
Widget _buildTimelineTab() {
  if (_isLoadingTimeline) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // Add condition to show message if no lessons
  if (_timelineItems.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No lessons available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new content',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  return Stack(
    children: [
      // Curved background
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Timeline header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Course Timeline',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${_timelineItems.length} Lessons',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      '${(_currentVideoIndex + 1).toString()}/${_timelineItems.length}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Timeline list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _timelineItems.length,
                itemBuilder: (context, index) {
                  final item = _timelineItems[index];
                  final isCurrentVideo = index == _currentVideoIndex;
                  final isCompleted = index < _currentVideoIndex;

                  return _buildTimelineItem(
                    item: item,
                    index: index,
                    isCurrentVideo: isCurrentVideo,
                    isCompleted: isCompleted,
                    isLast: index == _timelineItems.length - 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // Comments section - Show only when there are comments
      if (_comments.isEmpty) 
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: _showAddCommentDialog,
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ),
    ],
  );
}

Widget _buildTimelineItem({
  required Map<String, dynamic> item,
  required int index,
  required bool isCurrentVideo,
  required bool isCompleted,
  required bool isLast,
}) {
  return InkWell(
    onTap: () => _loadVideo(item['id'], item['src']),
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCurrentVideo 
                      ? AppColors.primary 
                      : isCompleted
                          ? AppColors.secondary
                          : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 2,
                    color: isCurrentVideo 
                        ? AppColors.primary 
                        : isCompleted 
                            ? AppColors.secondary 
                            : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Lesson content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentVideo 
                    ? AppColors.primary.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentVideo
                      ? AppColors.primary
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Lesson ${index + 1}',
                        style: TextStyle(
                          color: isCurrentVideo 
                              ? AppColors.primary
                              : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item['duration'],
                        style: TextStyle(
                          color: isCurrentVideo 
                              ? AppColors.primary
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title'],
                    style: TextStyle(
                      fontWeight: isCurrentVideo 
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isCurrentVideo 
                          ? AppColors.primary
                          : Colors.black87,
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

  void _showAddCommentDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Comment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Write your comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _addComment();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Post Comment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

Future<void> _loadComments() async {
  await _loadCommentsOperation?.cancel();
  
  if (!mounted) return;
  setState(() => _isLoadingComments = true);
  
  _loadCommentsOperation = CancelableOperation<List<Comment>>.fromFuture(
    Future<List<Comment>>(() async {
      try {
        debugPrint('Loading comments for courseId: ${widget.courseId}, chapterId: $_currentChapterId');
        
        final commentsSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('courses/${widget.courseId}/content/$_currentChapterId/comments')
            .get();

        if (!mounted) return [];

        debugPrint('Comments snapshot exists: ${commentsSnapshot.exists}');
        debugPrint('Comments value: ${commentsSnapshot.value}');

        if (!commentsSnapshot.exists || commentsSnapshot.value == null) {
          if (mounted) {
            setState(() {
              _comments = [];
              _isLoadingComments = false;
            });
          }
          return [];
        }

        final commentsMap = commentsSnapshot.value as Map<dynamic, dynamic>;
        final List<Comment> newComments = [];

        // Fetch all user data at once
        final userIds = commentsMap.values
            .map((c) => (c as Map)['userId'].toString())
            .toSet()
            .toList();
        
        final userDataSnapshot = await FirebaseDatabase.instance
            .ref()
            .child('users')
            .get();

        final usernames = <String, String>{};
        if (userDataSnapshot.exists && userDataSnapshot.value != null) {
          final userData = userDataSnapshot.value as Map<dynamic, dynamic>;
          for (final userId in userIds) {
            usernames[userId] = userData[userId]?['name']?.toString() ?? 'Anonymous';
          }
        }

        commentsMap.forEach((key, value) {
          if (value is Map) {
            final commentData = Map<String, dynamic>.from(value);
            final userId = commentData['userId'].toString();
            newComments.add(Comment(
              id: key.toString(),
              text: commentData['text'] ?? '',
              userId: userId,
              username: usernames[userId] ?? 'Anonymous',
              timestamp: commentData['timestamp'] as int,
            ));
          }
        });

        // Sort comments by timestamp in descending order (newest first)
        newComments.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (mounted) {
          setState(() {
            _comments = newComments;
            _isLoadingComments = false;
          });
          debugPrint('Loaded ${_comments.length} comments');
        }
        
        return newComments;
      } catch (e) {
        debugPrint('Error loading comments: $e');
        if (mounted) {
          setState(() {
            _isLoadingComments = false;
            _comments = [];
          });
        }
        return [];
      }
    })
  );

  await _loadCommentsOperation?.value;
}

Widget _buildCommentsTab() {
  if (_isLoadingComments) {
    return const Center(child: CircularProgressIndicator());
  }

  return Column(
    children: [
      Expanded(
        child: _comments.isEmpty 
            ? _buildEmptyComments()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _comments.length,
                itemBuilder: (context, index) => _buildCommentCard(_comments[index]),
              ),
      ),
      _buildCommentInput(),
    ],
  );
}

// Add comment input builder
Widget _buildCommentInput() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Add a comment...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        const SizedBox(width: 8),
        MaterialButton(
          onPressed: _addComment,
          color: AppColors.primary,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
          child: const Icon(Icons.send, color: Colors.white),
        ),
      ],
    ),
  );
}

Future<void> _addComment() async {
  if (_commentController.text.trim().isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final newComment = {
      'text': _commentController.text.trim(),
      'userId': user.uid,
      'timestamp': ServerValue.timestamp,
    };

    await FirebaseDatabase.instance
        .ref()
        .child('courses/${widget.courseId}/content/$_currentChapterId/comments')
        .push()
        .set(newComment);

    _commentController.clear();
    await _loadComments();

  } catch (e) {
    debugPrint('Error adding comment: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add comment. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Widget _buildCommentCard(Comment comment) {
    final userInitials = comment.username.isNotEmpty 
        ? comment.username.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCommentOwner = currentUser?.uid == comment.userId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  userInitials,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: userInitials.length > 1 ? 14 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isCommentOwner) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCommentOwner)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red,
                ),
                onPressed: () => _deleteComment(comment.id),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to comment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('courses/${widget.courseId}/content/$_currentChapterId/comments/$commentId')
            .remove();
        await _loadComments();
      } catch (e) {
        debugPrint('Error deleting comment: $e');
      }
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Add this method to handle system orientation changes
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _checkOrientation();
  }

  void _checkOrientation() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape != _isFullScreen) {
      setState(() => _isFullScreen = isLandscape);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Auto-pause video when app goes to background
      _videoPlayerController?.pause();
    }
  }

  // Add other required WidgetsBindingObserver methods
  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  Future<bool> didPopRoute() async => false;

  @override
  Future<bool> didPushRoute(String route) async => false;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async => false;

  // Add this method to show video options
  void _showVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.black87,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.white),
              title: const Text('Playback Speed',
                  style: TextStyle(color: Colors.white)),
              trailing: Text('${_playbackSpeed}x',
                  style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showPlaybackSpeedDialog();
              },
            ),
            // Add more options as needed
          ],
        ),
      ),
    );
  }

  // Add this method for showing playback speed dialog
  void _showPlaybackSpeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Playback Speed',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
            return ListTile(
              title: Text('${speed}x',
                  style: const TextStyle(color: Colors.white)),
              selected: _playbackSpeed == speed,
              onTap: () {
                _setPlaybackSpeed(speed);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Add this method
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0 
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  // Add these new methods for handling zoom gestures
  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
    setState(() {
      _previousScale = _currentScale;
      _isUserInteracting = true;
    });
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size;
    final videoRatio = _videoPlayerController?.value.aspectRatio ?? 16/9;
    
    setState(() {
      // Update scale
      _currentScale = (_baseScale * details.scale).clamp(_minScale, _maxScale);
      
      // Only allow panning when zoomed in
      if (_currentScale > 1.0) {
        final newPosition = _position + details.focalPointDelta;
        
        // Calculate bounds based on screen size and zoom level
        final scaledSize = Size(
          screenSize.width * (_currentScale - 1),
          screenSize.height * (_currentScale - 1),
        );
        
        final maxOffset = Offset(
          scaledSize.width / 2,
          scaledSize.height / 2,
        );
        
        // Apply bounds
        _position = Offset(
          newPosition.dx.clamp(-maxOffset.dx, maxOffset.dx),
          newPosition.dy.clamp(-maxOffset.dy, maxOffset.dy),
        );
      }
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    setState(() {
      _isUserInteracting = false;
      if (_currentScale <= _minScale) {
        _currentScale = _minScale;
        _position = Offset.zero;
      }
    });
    _resetHideControlsTimer();
  }

  // 1. Add a helper to choose video URL based on network speed:
String _selectVideoUrl(Map<String, dynamic> chapter) {
  // (For demo, use a dummy check; in real app, use connectivity plugin or measured latency)
  // If network is slow, return a lower quality URL if available (assume chapter contains "src_low").
  // Otherwise return default "src".
  if ((chapter['src_low'] ?? '') != '') {
    // add your network measurement logic here
    return chapter['src_low'];
  }
  return chapter['src'];
}

Future<void> _initializePlayer() async {
    if (!mounted) return;
    setState(() {
      _isBuffering = true;
      _errorMessage = null;
    });
    try {
      await _disposeCurrentController();
      
      // Check for last played video first
      final lastPlayed = _storageService.getLastPlayedVideo();
      String? chapterId = 'ch1';
      Duration? startPosition;
      
      if (lastPlayed != null && 
          lastPlayed['courseId'] == widget.courseId) {
        chapterId = lastPlayed['chapterId'] as String?;
        startPosition = Duration(milliseconds: lastPlayed['position'] as int);
      }

      final videoData = await _fetchVideoData(widget.courseId, chapterId ?? 'ch1');
      final chapter = videoData['currentChapter']!;
      final videoUrl = _selectVideoUrl(chapter);
      
      debugPrint('Initializing player with URL: $videoUrl');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      
      // Seek to last position if available
      if (startPosition != null) {
        await controller.seekTo(startPosition);
      }
      
      await controller.play();

      if (!mounted) return;
      setState(() {
        _videoPlayerController = controller;
        _isInitialized = true;
        _isBuffering = false;
        _currentChapterId = chapterId ?? 'ch1';
      });
      _videoPlayerController?.addListener(_videoPlayerListener);

    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _errorMessage = _getDetailedErrorMessage(e);
          _isBuffering = false;
          _isInitialized = false;
        });
      }
    }
  }

// 2. Create minimal LessonCard and CommentCard widgets:
Widget _buildLessonCard(Map<String, dynamic> item, bool isCurrent, bool isCompleted) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    elevation: isCurrent ? 4 : 1,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent ? AppColors.primary : Colors.grey[300],
        child: isCompleted ? const Icon(Icons.check, color: Colors.white)
          : isCurrent ? const Icon(Icons.play_arrow, color: Colors.white)
          : Text('${item['sno'] ?? ''}'),
      ),
      title: Text(
        item['title'] ?? 'Untitled Lesson',
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        item['duration'] ?? '',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => _loadVideo(item['id'], item['src']),
    ),
  );
}

Widget _buildCommentCardWidget(Comment comment, bool isOwner) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
    elevation: 1,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withOpacity(0.1),
        child: Text(
          comment.username.isNotEmpty
              ? comment.username[0].toUpperCase()
              : '?',
          style: const TextStyle(color: AppColors.primary),
        ),
      ),
      title: Text(
        comment.username,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        comment.text,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: isOwner
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _deleteComment(comment.id),
            )
          : null,
    ),
  );
}

// 3. Modify _buildTimelineTab to use LessonCard:
Widget _buildTimelineTabNew() { // Renamed from _buildTimelineTab
  if (_isLoadingTimeline) {
    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
  }
  if (_timelineItems.isEmpty) {
    return const Center(child: Text('No lessons available'));
  }
  return ListView.builder(
    padding: const EdgeInsets.only(top: 8),
    itemCount: _timelineItems.length,
    itemBuilder: (context, index) {
      final item = _timelineItems[index];
      final isCurrent = index == _currentVideoIndex;
      final isCompleted = index < _currentVideoIndex;
      return _buildLessonCard(item, isCurrent, isCompleted);
    },
  );
}

// 4. Modify _buildCommentsTab to use CommentCard:
Widget _buildCommentsTabNew() { // Renamed from _buildCommentsTab
  if (_isLoadingComments) {
    return const Center(child: CircularProgressIndicator());
  }

  return Column(
    children: [
      // Comments list with Expanded to take remaining space
      Expanded(
        child: _comments.isEmpty
            ? _buildEmptyComments()
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final isOwner = FirebaseAuth.instance.currentUser?.uid == comment.userId;
                  return _buildCommentCardWidget(comment, isOwner);
                },
              ),
      ),
      // Fixed comment input at bottom
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1),
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            MaterialButton(
              onPressed: () {
                _addComment();
                FocusScope.of(context).unfocus();
              },
              shape: const CircleBorder(),
              color: AppColors.primary,
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// 5. (Optional) Tweak the overall UI in build() or _buildVideoContent 
// to have minimal overlays and smoother animations similar to YouTube.
// For example, you may decrease the opacity of gradient overlays or remove extra shadows.
// ...existing build() and _buildVideoContent() remain mostly unchanged...
// ...existing code...

// Add this method to save current video position
void _saveCurrentPosition() {
  if (_videoPlayerController?.value.position != null && 
      _videoPlayerController?.value.isPlaying != null) {  // Changed check to isPlaying
    _storageService.saveVideoPosition(
      courseId: widget.courseId,
      chapterId: _currentChapterId,
      position: _videoPlayerController!.value.position,
    );

    // Also save last viewed details
    final duration = _videoPlayerController!.value.duration;
    if (duration.inMilliseconds > 0) {  // Add safety check
      final progress = _videoPlayerController!.value.position.inMilliseconds / 
                      duration.inMilliseconds;
      _storageService.saveLastViewedVideoDetails(
        courseId: widget.courseId,
        chapterId: _currentChapterId,
        progress: progress,
      );
    }
  }
}

}

class Comment {
  final String id;
  final String text;
  final String userId;
  final String username;
  final int timestamp;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.username,
    required this.timestamp,
  });

  factory Comment.fromMap(String id, Map data) {
    return Comment(
      id: id,
      text: data['text'] ?? '',
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Anonymous',
      timestamp: data['timestamp'] ?? 0,
    );
  }
}
