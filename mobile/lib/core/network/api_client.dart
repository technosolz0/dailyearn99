import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:target99/core/constants/api_constants.dart';
import 'package:target99/core/network/secure_storage_service.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorageService _secureStorage;
  String? _token;

  ApiClient(this._secureStorage)
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(ConnectivityInterceptor());
    _dio.interceptors.add(InterceptorsWrapper(
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
          
          // Avoid infinite loops by checking retry flag and preventing refresh on auth endpoints
          final isAuthEndpoint = path.contains('/auth/refresh') || path.contains('/auth/verify-otp');
          final isRetry = requestOptions.extra['isRetry'] == true;

          if (!isAuthEndpoint && !isRetry) {
            final refreshToken = await _secureStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Use a separate Dio instance to avoid interceptor side-effects during refresh
                final refreshDio = Dio(BaseOptions(
                  baseUrl: ApiConstants.baseUrl,
                  connectTimeout: const Duration(seconds: 15),
                  receiveTimeout: const Duration(seconds: 15),
                ));
                
                final refreshResponse = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );

                if (refreshResponse.statusCode == 200 || refreshResponse.statusCode == 201) {
                  final newAccessToken = refreshResponse.data['access_token'] as String;
                  final newRefreshToken = refreshResponse.data['refresh_token'] as String;

                  // Save new tokens securely
                  await saveTokens(accessToken: newAccessToken, refreshToken: newRefreshToken);

                  // Update request header and retry
                  requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
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
              }
            } else {
              // No refresh token, clear tokens
              await clearTokens();
            }
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<void> initializeTokens() async {
    _token = await _secureStorage.getAccessToken();
  }

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
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

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters);
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
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!kIsWeb) {
      try {
        final interfaces = await NetworkInterface.list();
        if (interfaces.isEmpty) {
          return handler.reject(
            DioException(
              requestOptions: options,
              message: 'No internet connection. Please check your network and try again.',
              type: DioExceptionType.connectionError,
            ),
          );
        }
      } catch (_) {
        // Fallback: ignore interface listing errors
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isConnectionError = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (isConnectionError) {
      final customError = DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        message: 'No internet connection. Please check your network and try again.',
        error: err.error,
      );
      return handler.next(customError);
    }
    return handler.next(err);
  }
}
