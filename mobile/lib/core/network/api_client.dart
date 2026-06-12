import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/secure_storage_service.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorageService _secureStorage;
  String? _token;
  void Function()? onUnauthenticated;

  ApiClient(this._secureStorage)
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(ConnectivityInterceptor());
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          final response = e.response;
          if (response != null && response.statusCode == 401) {
            final requestOptions = e.requestOptions;
            final path = requestOptions.path;

            final isVerifyOtpEndpoint = path.contains('/auth/verify-otp');
            final isRefreshEndpoint = path.contains('/auth/refresh');
            final isRetry = requestOptions.extra['isRetry'] == true;

            if (!isVerifyOtpEndpoint) {
              if (!isRefreshEndpoint && !isRetry) {
                final refreshToken = await _secureStorage.getRefreshToken();
                if (refreshToken != null) {
                  try {
                    // Use a separate Dio instance to avoid interceptor side-effects during refresh
                    final refreshDio = Dio(
                      BaseOptions(
                        baseUrl: ApiConstants.baseUrl,
                        connectTimeout: const Duration(seconds: 15),
                        receiveTimeout: const Duration(seconds: 15),
                      ),
                    );

                    final refreshResponse = await refreshDio.post(
                      '/auth/refresh',
                      data: {'refresh_token': refreshToken},
                    );

                    if (refreshResponse.statusCode == 200 ||
                        refreshResponse.statusCode == 201) {
                      final newAccessToken =
                          refreshResponse.data['access_token'] as String;
                      final newRefreshToken =
                          refreshResponse.data['refresh_token'] as String;

                      // Save new tokens securely
                      await saveTokens(
                        accessToken: newAccessToken,
                        refreshToken: newRefreshToken,
                      );

                      // Update request header and retry
                      requestOptions.headers['Authorization'] =
                          'Bearer $newAccessToken';
                      requestOptions.extra['isRetry'] = true;

                      final retryResponse = await _dio.request(
                        requestOptions.path,
                        options: Options(
                          method: requestOptions.method,
                          headers: requestOptions.headers,
                          extra: requestOptions.extra,
                        ),
                        data: requestOptions.data,
                        queryParameters: requestOptions.queryParameters,
                      );
                      return handler.resolve(retryResponse);
                    }
                  } catch (refreshError) {
                    // Refresh failed, clear tokens and let error propagate
                    await clearTokens();
                    onUnauthenticated?.call();
                  }
                } else {
                  // No refresh token, clear tokens
                  await clearTokens();
                  onUnauthenticated?.call();
                }
              } else {
                // If it is the refresh endpoint itself that returned 401, or already a retry that failed
                await clearTokens();
                onUnauthenticated?.call();
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> initializeTokens() async {
    _token = await _secureStorage.getAccessToken();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _token = accessToken;
    await _secureStorage.saveAccessToken(accessToken);
    await _secureStorage.saveRefreshToken(refreshToken);
  }

  Future<void> clearTokens() async {
    _token = null;
    await _secureStorage.clearTokens();
  }

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException error) {
    final response = error.response;
    if (response != null && response.data != null) {
      final data = response.data;
      if (data is Map && data.containsKey('detail')) {
        return Exception(data['detail'].toString());
      }
    }
    return Exception(error.message ?? 'An unknown connection error occurred');
  }
}

class ConnectivityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Proceed immediately to avoid blocking native channel calls on every request.
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isConnectionError =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (isConnectionError) {
      String message =
          'Failed to connect to the server. Please check your network and try again.';
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        final hasConnection = connectivityResult.any(
          (result) => result != ConnectivityResult.none,
        );
        if (!hasConnection) {
          message =
              'No internet connection. Please connect to Wi-Fi or mobile data and try again.';
        } else {
          message =
              'Server is unreachable. Please verify the backend server is running and try again.';
        }
      } catch (e) {
        print('Connectivity check error in onError: $e');
      }

      final customError = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        message: message,
        error: err.error,
      );
      return handler.next(customError);
    }
    return handler.next(err);
  }
}
