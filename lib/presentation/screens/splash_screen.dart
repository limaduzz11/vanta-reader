import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';

/// Tela de Abertura e Carregamento Animado da VANTA Labz
class SplashScreen extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onFinished;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2000),
    this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    _timer = Timer(widget.duration, () {
      if (mounted) {
        if (widget.onFinished != null) {
          widget.onFinished!();
        } else {
          context.go('/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NovaColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 280,
                        maxHeight: 160,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: NovaSpacing.md,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          NovaShapes.radiusSm,
                        ),
                        child: Image.asset(
                          'assets/branding/vanta_logo.jpeg',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'VANTA',
                              style: NovaTypography.displayMedium.copyWith(
                                letterSpacing: 6.0,
                                fontWeight: FontWeight.bold,
                                color: NovaColors.textPrimary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.xl),
                    const SizedBox(
                      width: 140,
                      height: 2.5,
                      child: LinearProgressIndicator(
                        color: NovaColors.textPrimary,
                        backgroundColor: NovaColors.surfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: NovaSpacing.lg,
              child: Center(
                child: Text(
                  'Developed by VANTA Labz',
                  style: NovaTypography.caption.copyWith(
                    color: NovaColors.textSecondary,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
