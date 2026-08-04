import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mparticle_flutter_sdk/events/event_type.dart';
import 'package:mparticle_flutter_sdk/events/mp_event.dart';
import 'package:mparticle_flutter_sdk/mparticle_flutter_sdk.dart';
import 'package:mparticle_flutter_sdk_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'iOS fire-and-forget platform channel methods complete without hanging',
    (WidgetTester tester) async {
      if (!Platform.isIOS) {
        return;
      }

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 8));

      final initStatusFinder = find.textContaining('mParticle is initialized:');
      expect(initStatusFinder, findsOneWidget);
      final initStatusText = tester.widget<Text>(initStatusFinder).data ?? '';
      if (!initStatusText.contains('true')) {
        fail(
          'Example initialize() did not succeed ($initStatusText). '
          'Check MP_API_KEY/MP_API_SECRET or native init errors.',
        );
      }

      final sdk = MparticleFlutterSdk.instance;

      final event = MPEvent(
        eventName: 'integration_test_event',
        eventType: EventType.Other,
      );

      await sdk
          .logEvent(event)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              fail('logEvent hung waiting for iOS platform channel result');
            },
          );

      await sdk
          .setOptOut(false)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              fail(
                'first setOptOut hung waiting for iOS platform channel result',
              );
            },
          );
      await sdk
          .setOptOut(true)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              fail(
                'second setOptOut hung waiting for iOS platform channel result',
              );
            },
          );
    },
  );
}
