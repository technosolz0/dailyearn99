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
        'update_url':
            'https://play.google.com/store/apps/details?id=com.dailyearn99.dailyearn99',
        'admin_upi_id': 'pay.dailyearn99@icici',
        'admin_bank_holder': 'Dailyearn99 Technologies Private Limited',
        'admin_bank_name': 'ICICI Bank',
        'admin_bank_account': '999901234567',
        'admin_bank_ifsc': 'ICIC0000001',
        'admin_contact_phone': '+919999999999',
        'admin_contact_email': 'support@dailyearn99.com',
      });

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
