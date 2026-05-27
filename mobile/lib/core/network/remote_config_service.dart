import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      // Define safe offline baseline defaults
      await _remoteConfig.setDefaults(const {
        'min_version': '1.0.0',
        'latest_version': '1.0.0',
        'force_update': false,
        'update_url': 'https://play.google.com/store/apps/details?id=com.technosolz0.target99',
      });

      // Configure fetch timeouts and instant updates during dev execution
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 0),
      ));

      await fetchAndActivate();
    } catch (e) {
      print('Firebase Remote Config Initialization error: $e');
    }
  }

  Future<bool> fetchAndActivate() async {
    try {
      return await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('Firebase Remote Config Fetch/Activate error: $e');
      return false;
    }
  }

  String get minVersion => _remoteConfig.getString('min_version');
  String get latestVersion => _remoteConfig.getString('latest_version');
  bool get forceUpdate => _remoteConfig.getBool('force_update');
  String get updateUrl => _remoteConfig.getString('update_url');
}
