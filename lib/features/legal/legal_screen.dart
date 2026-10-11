import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// The two legal documents, bundled as Markdown so the same text can also be
/// published on the web for the store listings.
enum LegalDocument {
  privacy('Privacy policy', 'assets/legal/privacy_policy.md'),
  terms('Terms of use', 'assets/legal/terms_of_use.md');

  const LegalDocument(this.title, this.asset);

  final String title;
  final String asset;
}

/// Shows a legal document. Reachable without signing in, since Welcome links
/// to both before anyone has an account.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document, this.bundle});

  final LegalDocument document;

  /// Overridable for tests; the app's own bundle otherwise.
  final AssetBundle? bundle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: (bundle ?? DefaultAssetBundle.of(context))
              .loadString(document.asset),
          builder: (context, snapshot) {
            final text = snapshot.data;
            if (text == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenMargin,
                0,
                AppSpacing.screenMargin,
                AppSpacing.xl,
              ),
              children: markdownBlocks(context, text),
            );
          },
        ),
      ),
    );
  }
}

/// Renders the small Markdown subset the documents use: `#` and `##`
/// headings, paragraphs, `- ` bullets and `**bold**`. The document's own `#`
/// title is skipped, since the app bar already shows it.
List<Widget> markdownBlocks(BuildContext context, String markdown) {
  final widgets = <Widget>[];
  final paragraph = <String>[];

  void flush() {
    if (paragraph.isEmpty) return;
    widgets.add(Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text.rich(_inline(context, paragraph.join(' '))),
    ));
    paragraph.clear();
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.startsWith('# ')) {
      flush();
    } else if (line.startsWith('## ')) {
      flush();
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Text(line.substring(3), style: context.text.headlineSmall),
      ));
    } else if (line.startsWith('- ')) {
      flush();
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: context.text.bodyMedium),
            Expanded(child: Text.rich(_inline(context, line.substring(2)))),
          ],
        ),
      ));
    } else if (line.isEmpty) {
      flush();
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return widgets;
}

/// Splits on `**` so alternate runs are bold.
TextSpan _inline(BuildContext context, String text) {
  final base = context.text.bodyMedium.copyWith(color: context.colors.textPrimary);
  final parts = text.split('**');
  return TextSpan(
    style: base,
    children: [
      for (final (i, part) in parts.indexed)
        TextSpan(
          text: part,
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
    ],
  );
}
