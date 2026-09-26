import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/brand.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({required this.initialize, required this.child, super.key});

  final Future<void> Function() initialize;
  final Widget child;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late Future<void> _initialization;
  Timer? _messageTimer;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..repeat();
    _start();
  }

  void _start() {
    _messageTimer?.cancel();
    _showMessage = false;
    _initialization = widget.initialize();
    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showMessage = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _ringController.stop();
    } else {
      if (!_ringController.isAnimating) _ringController.repeat();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        _messageTimer?.cancel();
        _ringController.stop();
        return AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          child: KeyedSubtree(
            key: const ValueKey('app-ready'),
            child: widget.child,
          ),
        );
      }
      return _StartupScreen(
        ringAnimation: _ringController,
        showMessage: _showMessage,
        error: snapshot.error,
        onRetry: () => setState(_start),
      );
    },
  );
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.ringAnimation,
    required this.showMessage,
    required this.error,
    required this.onRetry,
  });

  final Animation<double> ringAnimation;
  final bool showMessage;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFF101311),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: error == null
                      ? 'Prova Social carregando'
                      : 'Não foi possível iniciar o aplicativo',
                  child: SizedBox.square(
                    dimension: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const RepaintBoundary(child: BrandMark(size: 100)),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: ringAnimation,
                            builder: (context, _) => CustomPaint(
                              painter: _LoadingRingPainter(
                                ringProgress: reduceMotion
                                    ? 0
                                    : ringAnimation.value,
                                showError: error != null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Prova Social',
                  style: TextStyle(
                    color: Color(0xFFF3F7F4),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.6,
                  ),
                ),
                const SizedBox(height: 9),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Text(
                    error != null
                        ? 'Não foi possível iniciar agora.'
                        : showMessage
                        ? 'Preparando seu espaço de estudo…'
                        : 'Carregando…',
                    key: ValueKey('$showMessage-${error != null}'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF9EAAA3),
                      fontSize: 14,
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF19D88C),
                      foregroundColor: const Color(0xFF052017),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingRingPainter extends CustomPainter {
  const _LoadingRingPainter({
    required this.ringProgress,
    required this.showError,
  });

  final double ringProgress;
  final bool showError;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ringRect = Rect.fromCenter(
      center: center,
      width: size.width - 8,
      height: size.height - 8,
    );
    final ringColor = showError
        ? const Color(0xFFFF6B69)
        : const Color(0xFF19D88C);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          ringColor.withValues(alpha: .08),
          ringColor.withValues(alpha: .45),
          ringColor,
          ringColor.withValues(alpha: .08),
        ],
        stops: const [0, .56, .82, 1],
        transform: GradientRotation(ringProgress * math.pi * 2),
      ).createShader(ringRect);
    canvas.drawOval(ringRect, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingRingPainter oldDelegate) =>
      oldDelegate.ringProgress != ringProgress ||
      oldDelegate.showError != showError;
}
