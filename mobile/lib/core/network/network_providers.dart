import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/env.dart';
import 'auth_token_storage.dart';
import 'interceptors/auth_interceptor.dart';

part 'network_providers.g.dart';

@riverpod
AuthTokenStorage authTokenStorage(Ref ref) => AuthTokenStorage.instance;

@riverpod
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiHost,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: ref.watch(authTokenStorageProvider),
      baseUrl: Env.apiHost,
    ),
  );
  return dio;
}
