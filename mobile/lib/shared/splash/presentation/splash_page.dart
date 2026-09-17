import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/auth_token_storage.dart';

/// Cek sesi singkat lalu arahkan: sudah login -> home (shell), belum ->
/// login. Login sebagai tamu (isAuth false) juga mendarat di login page
/// dengan opsi "Lanjut tanpa login".
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isAuth = await AuthTokenStorage.instance.getIsAuth();
      if (!mounted) return;
      context.go(isAuth ? '/' : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
