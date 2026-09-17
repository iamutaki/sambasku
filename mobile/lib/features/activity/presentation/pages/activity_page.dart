import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Tab ACTION - placeholder. Akan menjadi pusat kontribusi:
/// usul kata (anonim/login), kontribusi media, status kontribusi
/// (roadmap mobile-base-stack Section 12 tahap 4-5).
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontribusi')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 56, color: Colors.grey),
            Gap(8),
            Text('Fitur kontribusi menyusul'),
            Gap(4),
            Text(
              'Usul kata baru & kontribusi media akan hidup di sini',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
