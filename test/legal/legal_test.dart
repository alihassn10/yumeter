import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/core/theme/app_theme.dart';
import 'package:yumeter/features/legal/legal_screen.dart';

void main() {
  test('both documents exist and keep their required sections', () {
    final privacy = File('assets/legal/privacy_policy.md').readAsStringSync();
    final terms = File('assets/legal/terms_of_use.md').readAsStringSync();

    // Stores reject a policy that hides who handles data or how to delete it.
    for (final heading in [
      '## What we collect',
      '## Who else handles your data',
      '## How long we keep it',
      '## Your choices and rights',
    ]) {
      expect(privacy, contains(heading));
    }
    expect(privacy, contains('Google (Gemini API)'));
    expect(privacy, contains('Open Food Facts'));
    expect(terms, contains('not medical advice'));
  });

  testWidgets('renders headings, bullets and bold text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => ListView(
            children: markdownBlocks(
              context,
              '# Title\n\n'
              'Intro **bold part** end.\n\n'
              '## Section\n\n'
              '- first item\n'
              '- second item\n',
            ),
          ),
        ),
      ),
    ));

    // The document title is left to the app bar.
    expect(find.text('Title'), findsNothing);
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Intro bold part end.'), findsOneWidget);
    expect(find.text('first item'), findsOneWidget);
    expect(find.text('second item'), findsOneWidget);
  });

  testWidgets('the screen loads its document from the bundle', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const LegalScreen(document: LegalDocument.terms),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Who can use Yumeter'), findsOneWidget);
  });
}
