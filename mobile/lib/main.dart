import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'flavors.dart';

/// Entry utama (staging default). Production lewat:
///   flutter run --dart-define=FLAVOR=production
/// Flavorizr ( nama app + ikon per flavor) disiapkan saat build rilis -
/// lihat mobile-base-stack.md Section 8.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final flavorName = const String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'staging',
  );
  F.appFlavor = Flavor.values.firstWhere(
    (element) => element.name == flavorName,
    orElse: () => Flavor.staging,
  );

  runApp(const ProviderScope(child: App()));
}
