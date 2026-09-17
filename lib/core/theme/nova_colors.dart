import 'package:flutter/material.dart';

/// Paleta de Cores Oficial do NovaReader — Monochromatic Minimalism
/// Baseada estritamente nas especificações:
/// Background: #121212
/// Primary Text: #E0E0E0
/// Secondary Text: #B0B0B0
/// Borders / Dividers: #444444
/// Accent: #888888
class NovaColors {
  NovaColors._();

  // Cores Primárias de Superfície e Fundo
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceSecondary = Color(0xFF262626);
  static const Color surfaceElevated = Color(0xFF2E2E2E);

  // Tipografia e Conteúdo
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF757575);

  // Bordas, Divisores e Contornos
  static const Color border = Color(0xFF444444);
  static const Color borderSubtle = Color(0xFF333333);
  static const Color divider = Color(0xFF444444);

  // Destaques e Acentos Neutros
  static const Color accent = Color(0xFF888888);
  static const Color accentLight = Color(0xFFAAAAAA);
  static const Color accentDark = Color(0xFF555555);

  // Estados Semânticos Discretos (Desaturados)
  static const Color error = Color(0xFFCF6679);
  static const Color success = Color(0xFF81C784);
  static const Color warning = Color(0xFFFFB74D);
  static const Color info = Color(0xFF64B5F6);

  // Overlays e Transparências
  static const Color scrim = Color(0x99000000);
  static const Color highlight = Color(0x1FFFFFFF);
}

/// Acento secundário do perfil (G-07). Paleta desaturada para preservar a
/// identidade monocromática; aplicada ao reiniciar (ver `NovaTheme`).
class VantaAccent {
  final String id;
  final String label;
  final Color color;

  const VantaAccent({
    required this.id,
    required this.label,
    required this.color,
  });

  static const List<VantaAccent> presets = [
    VantaAccent(id: 'grafite', label: 'Grafite', color: Color(0xFF888888)),
    VantaAccent(id: 'gelo', label: 'Gelo', color: Color(0xFF9AB5C7)),
    VantaAccent(id: 'sepia', label: 'Sépia', color: Color(0xFFB09A7A)),
    VantaAccent(id: 'musgo', label: 'Musgo', color: Color(0xFF8FA38A)),
    VantaAccent(id: 'ardosia', label: 'Ardósia', color: Color(0xFF7A8BA3)),
  ];

  static VantaAccent getById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }
}
