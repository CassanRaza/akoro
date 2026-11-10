import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';

/// Résultat d'un pointage réussi, renvoyé à l'écran Présence.
class ResultatPointage {
  final String action; // arrivee | depart
  final String message;
  const ResultatPointage(this.action, this.message);
}

/// Scan du QR code de la séance (ou saisie du code de secours à 6 caractères).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  static const _prefixe = 'AKORO-SEANCE:';

  final _camera = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_envoi || _erreur != null) return;
    final valeur = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (valeur == null) return;
    if (!valeur.startsWith(_prefixe)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Ce QR code n’est pas un QR de présence TA-Fablab.')));
      return;
    }
    await _envoyer(valeur);
  }

  Future<void> _envoyer(String code) async {
    final api = context.read<AuthProvider>().api;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    await _camera.stop();
    try {
      final json = await api.post('/presences/scanner', {'code': code});
      final data = Map<String, dynamic>.from(json as Map);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop(ResultatPointage('${data['action']}', '${data['message']}'));
    } on ApiException catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _reessayer() async {
    setState(() => _erreur = null);
    await _camera.start();
  }

  Future<void> _saisirCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SaisieCode(),
    );
    if (code != null && mounted) await _envoyer(code);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Scanner le QR de la séance', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              tooltip: 'Lampe',
              color: Colors.white,
              onPressed: () => _camera.toggleTorch(),
              icon: ValueListenableBuilder(
                valueListenable: _camera,
                builder: (_, etat, _) => Icon(etat.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              ),
            ),
            const ThemeToggleButton(color: Colors.white),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              errorBuilder: (context, erreur) => _CameraIndisponible(onSaisir: _saisirCode, detail: erreur.errorCode.name),
            ),
            const IgnorePointer(child: CustomPaint(painter: _Cadre())),
            // ---------- Consignes et actions ----------
            Positioned(
              left: 20,
              right: 20,
              bottom: 32,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_envoi)
                      const _Bulle(icon: Icons.sync, texte: 'Enregistrement du pointage…', chargement: true)
                    else if (_erreur != null)
                      _Bulle(icon: Icons.error_outline, texte: _erreur!, erreur: true)
                    else
                      const _Bulle(
                        icon: Icons.qr_code_scanner_rounded,
                        texte: 'Placez le QR code affiché par votre formateur dans le cadre.',
                      ),
                    const SizedBox(height: 14),
                    if (_erreur != null)
                      FilledButton.icon(onPressed: _reessayer, icon: const Icon(Icons.refresh), label: const Text('Scanner à nouveau')),
                    if (_erreur != null) const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                      onPressed: _envoi ? null : _saisirCode,
                      icon: const Icon(Icons.keyboard_alt_outlined),
                      label: const Text('Saisir le code de la séance'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Assombrit l'image autour d'un cadre carré aux coins arrondis.
class _Cadre extends CustomPainter {
  const _Cadre();

  @override
  void paint(Canvas canvas, Size size) {
    final cote = (size.shortestSide * 0.68).clamp(180.0, 320.0);
    final centre = Offset(size.width / 2, size.height * 0.42);
    final cadre = RRect.fromRectAndRadius(Rect.fromCenter(center: centre, width: cote, height: cote), const Radius.circular(24));

    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(cadre)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      cadre,
      Paint()
        ..color = Brand.tealLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Bulle extends StatelessWidget {
  final IconData icon;
  final String texte;
  final bool erreur, chargement;
  const _Bulle({required this.icon, required this.texte, this.erreur = false, this.chargement = false});

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: erreur ? const Color(0xF2B42318) : const Color(0xCC000000),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              chargement
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(texte, style: const TextStyle(color: Colors.white, height: 1.35, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      );
}

class _CameraIndisponible extends StatelessWidget {
  final VoidCallback onSaisir;
  final String detail;
  const _CameraIndisponible({required this.onSaisir, required this.detail});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
                const SizedBox(height: 16),
                Text(
                  detail == 'permissionDenied'
                      ? 'L’accès à la caméra est refusé. Autorisez-le dans les réglages du téléphone, ou saisissez le code de la séance.'
                      : 'La caméra n’est pas disponible. Saisissez le code de la séance affiché sous le QR.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: onSaisir, icon: const Icon(Icons.keyboard_alt_outlined), label: const Text('Saisir le code')),
              ],
            ),
          ),
        ),
      );
}

/// Saisie du code de secours (6 caractères, affiché sous le QR sur le web).
class _SaisieCode extends StatefulWidget {
  const _SaisieCode();

  @override
  State<_SaisieCode> createState() => _SaisieCodeState();
}

class _SaisieCodeState extends State<_SaisieCode> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valide = _code.text.length == 6;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Code de la séance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Saisissez les 6 caractères affichés sous le QR code.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => valide ? Navigator.pop(context, _code.text) : null,
            decoration: const InputDecoration(hintText: 'ABC123', counterText: ''),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: valide ? () => Navigator.pop(context, _code.text) : null,
            child: const Text('Valider le pointage'),
          ),
        ],
      ),
    );
  }
}
