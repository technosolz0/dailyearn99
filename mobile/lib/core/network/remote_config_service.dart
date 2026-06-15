import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  Future<void> initialize() async {
    try {
      // Configure fetch timeouts and instant updates during dev execution
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 2),
          minimumFetchInterval: const Duration(seconds: 0),
        ),
      );

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

  String get adminUpiId => _remoteConfig.getString('admin_upi_id');
  String get adminBankHolder => _remoteConfig.getString('admin_bank_holder');
  String get adminBankName => _remoteConfig.getString('admin_bank_name');
  String get adminBankAccount => _remoteConfig.getString('admin_bank_account');
  String get adminBankIfsc => _remoteConfig.getString('admin_bank_ifsc');
  String get adminContactPhone =>
      _remoteConfig.getString('admin_contact_phone');
  String get adminContactEmail =>
      _remoteConfig.getString('admin_contact_email');
}
