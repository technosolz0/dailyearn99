import 'package:get_it/get_it.dart';
import 'package:target99/core/network/api_client.dart';
import 'package:target99/core/network/secure_storage_service.dart';

final getIt = GetIt.instance;

void setupDependencyInjection() {
  // Register Secure Storage Service
  final secureStorage = SecureStorageService();
  getIt.registerSingleton<SecureStorageService>(secureStorage);

  // Register API Client as Singleton
  getIt.registerSingleton<ApiClient>(ApiClient(secureStorage));
}
