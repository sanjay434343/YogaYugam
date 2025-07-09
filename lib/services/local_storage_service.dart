import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  final SharedPreferences _prefs;
  static const _lastVideoKey = 'last_viewed_video';
  static const String _lastPlayedKey = 'last_played_video';
  static const String _videoPositionsKey = 'video_positions';

  LocalStorageService(this._prefs);

  Future<void> saveLastViewedVideo({
    required String courseId,
    String chapterId = '',
    double progress = 0.0,
    String title = '',
    String videoUrl = '',
    String thumbnailUrl = '',
  }) async {
    try {
      final videoData = {
        'courseId': courseId,
        'chapterId': chapterId,
        'title': title,
        'thumbnail': thumbnailUrl,
        'videoUrl': videoUrl,
        'progress': progress,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _prefs.setString(_lastVideoKey, jsonEncode(videoData));
    } catch (e) {
      print('Error saving last viewed video: $e');
    }
  }

  Map<String, dynamic>? getLastViewedVideo() {
    try {
      final data = _prefs.getString(_lastVideoKey);
      if (data == null) return null;
      
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      print('Error getting last viewed video: $e');
      return null;
    }
  }

  Future<void> clearLastViewedVideo() async {
    await _prefs.remove(_lastVideoKey);
  }

  // Store last viewed video details
  Future<void> saveLastViewedVideoDetails({
    required String courseId,
    required String chapterId,
    required double progress,
  }) async {
    await _prefs.setString('last_viewed_course_id', courseId);
    await _prefs.setString('last_viewed_chapter_id', chapterId);
    await _prefs.setDouble('last_viewed_progress', progress);
  }

  // Get last viewed video details
  Map<String, dynamic>? getLastViewedVideoDetails() {
    final courseId = _prefs.getString('last_viewed_course_id');
    final chapterId = _prefs.getString('last_viewed_chapter_id');
    final progress = _prefs.getDouble('last_viewed_progress');

    if (courseId == null || chapterId == null) return null;

    return {
      'courseId': courseId,
      'chapterId': chapterId,
      'progress': progress ?? 0.0,
    };
  }

  // Store purchased course
  Future<void> savePurchasedCourse(String courseId) async {
    final purchasedCourses = _prefs.getStringList('purchased_courses') ?? [];
    if (!purchasedCourses.contains(courseId)) {
      purchasedCourses.add(courseId);
      await _prefs.setStringList('purchased_courses', purchasedCourses);
    }
  }

  // Check if course is purchased
  bool isPurchased(String courseId) {
    final purchasedCourses = _prefs.getStringList('purchased_courses') ?? [];
    return purchasedCourses.contains(courseId);
  }

  Future<void> saveVideoPosition({
    required String courseId,
    required String chapterId,
    required Duration position,
  }) async {
    final key = '${courseId}_${chapterId}_position';
    await _prefs.setInt(key, position.inMilliseconds);
    
    // Save as last played video
    final lastPlayedData = {
      'courseId': courseId,
      'chapterId': chapterId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'position': position.inMilliseconds,
    };
    await _prefs.setString(_lastPlayedKey, json.encode(lastPlayedData));
  }

  Duration? getVideoPosition(String courseId, String chapterId) {
    final key = '${courseId}_${chapterId}_position';
    final milliseconds = _prefs.getInt(key);
    return milliseconds != null ? Duration(milliseconds: milliseconds) : null;
  }

  Map<String, dynamic>? getLastPlayedVideo() {
    final data = _prefs.getString(_lastPlayedKey);
    if (data != null) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearVideoPosition(String courseId, String chapterId) async {
    final key = '${courseId}_${chapterId}_position';
    await _prefs.remove(key);
  }
}
