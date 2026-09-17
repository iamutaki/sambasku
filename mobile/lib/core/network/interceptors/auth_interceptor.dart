import 'package:dio/dio.dart';

import '../auth_token_storage.dart';

/// Interceptor auth (pola jnn_mobile, varian sambasku):
/// - onRequest: sisipkan Bearer access token
/// - onError 401: refresh SEKALI (queue via _refreshFuture - beberapa
///   request 401 bersamaan menunggu satu refresh), lalu retry request;
///   gagal refresh -> clear token (router redirect ke login)
///
/// Refresh memakai varian mobile (base-stack Section 6):
/// POST /api/v1/auth/refresh body { refresh_token, client_type: 'mobile' }
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthTokenStorage tokenStorage,
    required String baseUrl,
  }) : _tokenStorage = tokenStorage,
       _refreshDio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 15),
           sendTimeout: const Duration(seconds: 15),
           headers: {
             'Accept': 'application/json',
             'Content-Type': 'application/json',
           },
         ),
       );

  final AuthTokenStorage _tokenStorage;
  final Dio _refreshDio;
  Future<bool>? _refreshFuture;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // lanjut tanpa header auth
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEndpoint = err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh');
    if (err.response?.statusCode != 401 || isAuthEndpoint) {
      return handler.next(err);
    }

    try {
      final refreshed = await _refreshToken();
      if (!refreshed) {
        await _tokenStorage.clearTokens();
        return handler.next(err);
      }

      // retry request dengan token baru
      final options = err.requestOptions;
      final newToken = await _tokenStorage.getAccessToken();
      if (newToken != null) {
        options.headers['Authorization'] = 'Bearer $newToken';
      }
      final response = await Dio().fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      await _tokenStorage.clearTokens();
      return handler.next(e);
    } catch (e) {
      return handler.next(err);
    }
  }

  /// Single-flight: request 401 bersamaan berbagi satu panggilan refresh
  Future<bool> _refreshToken() {
    return _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await _refreshDio.post(
        '/api/v1/auth/refresh',
        data: {
          'refresh_token': refreshToken,
          'client_type': 'mobile',
        },
      );
      final data = response.data['data'];
      if (data == null) return false;

      await _tokenStorage.saveTokens(
        accessToken: data['access_token'] as String? ?? '',
        refreshToken: data['refresh_token'] as String? ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
