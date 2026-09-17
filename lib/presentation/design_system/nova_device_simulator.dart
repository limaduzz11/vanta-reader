import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';

enum SimulatedDevice {
  responsive('Responsivo (Tela Cheia)', null, null),
  phone('Celular (393 × 852)', 393, 852),
  tablet('Tablet (800 × 1200)', 800, 1200);

  final String label;
  final double? width;
  final double? height;
  const SimulatedDevice(this.label, this.width, this.height);
}

/// Simulador de Dispositivos Embutido para Debug no Linux Desktop
class NovaDeviceSimulator extends StatefulWidget {
  final Widget child;

  const NovaDeviceSimulator({super.key, required this.child});

  @override
  State<NovaDeviceSimulator> createState() => _NovaDeviceSimulatorState();
}

class _NovaDeviceSimulatorState extends State<NovaDeviceSimulator> {
  SimulatedDevice _selectedDevice = SimulatedDevice.phone;
  bool _showFrame = true;

  @override
  Widget build(BuildContext context) {
    // O simulador de moldura/resolução destina-se EXCLUSIVAMENTE ao desenvolvimento no Desktop (Linux, macOS, Windows).
    // Em dispositivos móveis reais (Android, iOS) ou produção/testes, renderiza em tela cheia nativa sem barra.
    final isDesktop =
        !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    if (!kDebugMode ||
        !isDesktop ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return widget.child;
    }

    if (_selectedDevice == SimulatedDevice.responsive) {
      return Stack(children: [widget.child, _buildFloatingToolbar()]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Container(
                  width: _selectedDevice.width,
                  height: _selectedDevice.height,
                  decoration: BoxDecoration(
                    color: NovaColors.background,
                    borderRadius: BorderRadius.circular(
                      _selectedDevice == SimulatedDevice.phone ? 36.0 : 24.0,
                    ),
                    border: _showFrame
                        ? Border.all(
                            color: const Color(0xFF333333),
                            width: 10.0,
                          )
                        : null,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 30.0,
                        spreadRadius: 5.0,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _selectedDevice == SimulatedDevice.phone ? 26.0 : 14.0,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
          _buildFloatingToolbar(),
        ],
      ),
    );
  }

  Widget _buildFloatingToolbar() {
    return Positioned(
      top: 12.0,
      right: 16.0,
      child: Material(
        color: NovaColors.surfaceSecondary.withValues(alpha: 0.95),
        elevation: 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: NovaShapes.roundedMd,
          side: const BorderSide(color: NovaColors.border, width: 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.devices_rounded,
                size: 16,
                color: NovaColors.accent,
              ),
              const SizedBox(width: NovaSpacing.sm),
              DropdownButton<SimulatedDevice>(
                value: _selectedDevice,
                dropdownColor: NovaColors.surfaceSecondary,
                underline: const SizedBox.shrink(),
                isDense: true,
                style: NovaTypography.labelMedium.copyWith(fontSize: 12),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: NovaColors.textSecondary,
                  size: 18,
                ),
                items: SimulatedDevice.values.map((device) {
                  return DropdownMenuItem(
                    value: device,
                    child: Text(device.label),
                  );
                }).toList(),
                onChanged: (device) {
                  if (device != null) {
                    setState(() {
                      _selectedDevice = device;
                    });
                  }
                },
              ),
              const SizedBox(width: NovaSpacing.sm),
              IconButton(
                icon: Icon(
                  _showFrame
                      ? Icons.crop_portrait_rounded
                      : Icons.crop_square_rounded,
                  size: 16,
                  color: NovaColors.textMuted,
                ),
                tooltip: 'Alternar Moldura',
                onPressed: () {
                  setState(() {
                    _showFrame = !_showFrame;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
