import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/brand.dart';
import 'github_release_service.dart';

class UpdateGate extends StatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!checked && !kIsWeb) {
      checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    try {
      final release = await const GithubReleaseService().findUpdate();
      if (release == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const BrandMark(size: 52),
          title: const Text('Atualização disponível'),
          content: Text(
            'A versão ${release.version} do Prova Social já pode ser instalada. '
            'A atualização será baixada diretamente do GitHub.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Agora não'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await launchUrl(
                  release.downloadUrl,
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Baixar atualização'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Atualizações nunca devem impedir a abertura do aplicativo.
    }
  }

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.background, child: widget.child);
}
