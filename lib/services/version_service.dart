import 'package:firebase_database/firebase_database.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class VersionService {
  // Update path to match exact node name from Firebase
  final DatabaseReference _database = FirebaseDatabase.instance.ref().child('appversion');

  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      String currentVersion = AppConfig.currentVersion;
      debugPrint('Checking for updates. Current version: $currentVersion');

      // Get the appversion node data - removed child() call since we included it in constructor
      final DatabaseEvent event = await _database.once();
      final data = event.snapshot.value;
      debugPrint('Raw Firebase Realtime DB data: $data');

      if (data == null) {
        debugPrint('No data in Firebase Realtime DB');
        return null;
      }

      // Convert the data to a List and handle null values
      List<dynamic> versions = [];
      if (data is List) {
        versions = data.where((v) => v != null && v is Map).toList();
      }

      debugPrint('Parsed versions from Realtime DB: $versions');

      if (versions.isEmpty) {
        debugPrint('No valid versions found in list');
        return null;
      }

      // Find latest version
      Map<dynamic, dynamic>? latestVersion;
      String latestVersionStr = '0.0.0';

      for (var version in versions) {
        // Handle both version spellings due to typo in data
        String versionStr = version['version'] ?? version['verion'] ?? '0.0.0';
        debugPrint('Checking version entry: $versionStr');
        
        if (_compareVersions(versionStr, latestVersionStr) > 0) {
          latestVersionStr = versionStr;
          latestVersion = version;
          debugPrint('Found newer version: $latestVersionStr');
        }
      }

      if (latestVersion == null) {
        debugPrint('No valid version found after comparison');
        return null;
      }

      int compareResult = _compareVersions(latestVersionStr, currentVersion);
      debugPrint('Final comparison - Latest: $latestVersionStr, Current: $currentVersion, Result: $compareResult');

      if (compareResult > 0) {
        debugPrint('Update required - returning update info');
        return {
          'version': latestVersionStr,
          'url': AppConfig.downloadUrl, // Use constant URL instead of Firebase value
          'releaseNotes': latestVersion['releaseNotes'],
          'currentVersion': currentVersion,
        };
      }

      debugPrint('No update needed - current version is up to date');
      return null;

    } catch (e, stack) {
      debugPrint('Error accessing Realtime DB: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  int _compareVersions(String v1, String v2) {
    try {
      List<int> v1Parts = v1.split('.').map(int.parse).toList();
      List<int> v2Parts = v2.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        int v1Part = i < v1Parts.length ? v1Parts[i] : 0;
        int v2Part = i < v2Parts.length ? v2Parts[i] : 0;
        if (v1Part > v2Part) return 1;
        if (v1Part < v2Part) return -1;
      }
      return 0;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return 0;
    }
  }
}
