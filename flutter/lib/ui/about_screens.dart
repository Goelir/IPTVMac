import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptvmac/app/device.dart';
import 'package:iptvmac/l10n/app_localizations.dart';
import 'package:iptvmac/ui/onboarding.dart';
import 'package:iptvmac/ui/tv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyUrl = 'https://goelir.github.io/IPTVMac/privacy/';
const sourceUrl = 'https://github.com/Goelir/IPTVMac';

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {} // a TV may have no browser to open it with
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return TvFrame(
      child: Scaffold(
      appBar: AppBar(title: Text(l.settingsAbout)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const SizedBox(height: 12),
            const Center(child: LogoTile(size: 84)),
            const SizedBox(height: 14),
            Center(child: Text(l.appName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            const SizedBox(height: 4),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (_, s) => Text(s.hasData ? '${l.aboutVersion} ${s.data!.version} (${s.data!.buildNumber})' : l.aboutVersion, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 20),
            Text(l.onbNoChannels, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                ListTile(
                  key: const Key('privacy-link'),
                  autofocus: isTelevision,
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(l.aboutPrivacy),
                  subtitle: const Text('goelir.github.io/IPTVMac/privacy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => _open(privacyUrl),
                ),
                ListTile(
                  key: const Key('acks-tile'),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l.aboutAcknowledgements),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AcknowledgementsScreen())),
                ),
                ListTile(leading: const Icon(Icons.code), title: Text(l.aboutSource), trailing: const Icon(Icons.open_in_new, size: 18), onTap: () => _open(sourceUrl)),
              ]),
            ),
          ]),
        ),
      ),
      ),
    );
  }
}

/// The notices and licence texts (about 100 KB): a lazily built list of lines, not one giant text.
class AcknowledgementsScreen extends StatefulWidget {
  const AcknowledgementsScreen({super.key});
  @override
  State<AcknowledgementsScreen> createState() => _AcknowledgementsScreenState();
}

class _AcknowledgementsScreenState extends State<AcknowledgementsScreen> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TvFrame(
      child: Scaffold(
        appBar: AppBar(title: Text(l.aboutAcknowledgements)),
        body: FutureBuilder<String>(
          future: rootBundle.loadString('assets/Acknowledgements.md'),
          builder: (context, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final lines = s.data!.split('\n');
            final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
            return TvScrollKeys(
              controller: _scroll,
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: lines.length,
                  itemBuilder: (_, i) => Text(lines[i], style: style),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
