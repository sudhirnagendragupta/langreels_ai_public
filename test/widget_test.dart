// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langreels_ai/main.dart';

void main() {
  testWidgets('LangReels app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester
        .pumpWidget(LangReelsApp()); // Changed from MyApp to LangReelsApp

    // Verify that our app starts (this is a basic smoke test)
    // Since the app requires Firebase initialization, we'll just check if it builds
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
