import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yt_offline/app.dart';

void main() {
  testWidgets('Search screen renders', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YtOfflineApp()));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });
}
