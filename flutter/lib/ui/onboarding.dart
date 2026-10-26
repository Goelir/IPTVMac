import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/app/source_draft.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/missing_strings.dart';
import 'package:iptvmac/ui/source_form.dart';
import 'package:iptvmac/ui/theme.dart';

/// The app icon, drawn: the logo's blue-to-violet tile with a TV mark.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, this.size = 112});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.225),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5C8CF0), Color(0xFF7A4FE0)]),
            boxShadow: [BoxShadow(color: const Color(0xFF4D33CC).withValues(alpha: 0.4), blurRadius: size * 0.28, offset: Offset(0, size * 0.12))],
          ),
          child: Icon(Icons.live_tv_rounded, size: size * 0.5, color: Colors.white),
        ),
      );
}

/// First run (no sources yet): who we are, what is not included, and how to add a source.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _open(BuildContext context, [SourceDraft? draft]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SourceFormScreen(initial: draft)));

  Future<void> _paste(BuildContext context) async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text == null || text.isEmpty || !context.mounted) return;
    _open(context, SourceDraft()..applyPasted(text));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topCenter, radius: 1.1, colors: [Brand.accentFill.withValues(alpha: 0.28), Colors.transparent])),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const LogoTile(),
                        const SizedBox(height: 24),
                        Semantics(header: true, child: Text(l.onbWelcomeTitle, textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
                        const SizedBox(height: 10),
                        Text(l.onbWelcomeBody, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.normal)),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: cs.surfaceContainerLow.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(Icons.info_outline, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(l.onbNoChannels, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
                          ]),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          key: const Key('add-source'),
                          autofocus: isTelevision,
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          onPressed: () => _open(context),
                          child: Text(l.accountAdd),
                        ),
                        if (!isTelevision) ...[ // a TV has no clipboard to paste a link from
                          const SizedBox(height: 12),
                          Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
                            Text(l.onbPasteHint, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                            OutlinedButton.icon(onPressed: () => _paste(context), icon: const Icon(Icons.content_paste, size: 18), label: Text(Missing.paste)),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
