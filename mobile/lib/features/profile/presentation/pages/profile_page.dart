import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Tab PROFILE - placeholder. Akan menampilkan info user, logout,
/// dan pengaturan (roadmap tahap 6).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 56, color: Colors.grey),
            Gap(8),
            Text('Profil menyusul'),
            Gap(4),
            Text(
              'Info user, logout, dan pengaturan akan hidup di sini',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
