import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sambasku_mobile/app.dart';
import 'package:sambasku_mobile/flavors.dart';

void main() {
  // test tidak melewati main() - flavor wajib di-init manual
  setUpAll(() => F.appFlavor = Flavor.staging);

  testWidgets('App bootstrap - splash terender tanpa error', (
    WidgetTester tester,
  ) async {
    // plugin SharedPreferences tidak tersedia di test env - mock values
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const App());
    await tester.pump();

    // splash masih tampil (redirect async), Scaffold ada = bootstrap oke
    expect(find.byType(Scaffold), findsWidgets);
  });
}
