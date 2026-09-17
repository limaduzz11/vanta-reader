import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';

/// Definição de Avatar Abstrato / Geométrico Monocromático
class NovaAvatarPreset {
  final String id;
  final String label;
  final IconData icon;

  const NovaAvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
  });

  static const List<NovaAvatarPreset> presets = [
    NovaAvatarPreset(
      id: 'nova_monolith',
      label: 'Monolito',
      icon: Icons.crop_portrait_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_circle',
      label: 'Eclipse',
      icon: Icons.radio_button_checked_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_book',
      label: 'Tomo',
      icon: Icons.auto_stories_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_comic',
      label: 'Quadro',
      icon: Icons.dashboard_customize_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_eye',
      label: 'Sentinela',
      icon: Icons.remove_red_eye_outlined,
    ),
    NovaAvatarPreset(
      id: 'nova_star',
      label: 'Constelação',
      icon: Icons.star_border_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_cube',
      label: 'Voxel',
      icon: Icons.view_in_ar_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_shield',
      label: 'Baluarte',
      icon: Icons.shield_outlined,
    ),
    NovaAvatarPreset(
      id: 'nova_prism',
      label: 'Prisma',
      icon: Icons.change_history_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_helix',
      label: 'Espiral',
      icon: Icons.all_inclusive_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_horizon',
      label: 'Horizonte',
      icon: Icons.linear_scale_rounded,
    ),
    NovaAvatarPreset(
      id: 'nova_compass',
      label: 'Compasso',
      icon: Icons.explore_outlined,
    ),
    // G-07: arquétipos de domínio público (referências originais, sem marcas).
    NovaAvatarPreset(
      id: 'vanta_detetive',
      label: 'Detetive',
      icon: Icons.manage_search_rounded,
    ),
    NovaAvatarPreset(
      id: 'vanta_explorador',
      label: 'Explorador',
      icon: Icons.public_rounded,
    ),
    NovaAvatarPreset(
      id: 'vanta_cientista',
      label: 'Cientista',
      icon: Icons.science_outlined,
    ),
    NovaAvatarPreset(
      id: 'vanta_notivago',
      label: 'Notívago',
      icon: Icons.nightlight_round,
    ),
    NovaAvatarPreset(
      id: 'vanta_automato',
      label: 'Autômato',
      icon: Icons.smart_toy_outlined,
    ),
    NovaAvatarPreset(
      id: 'vanta_navegante',
      label: 'Navegante',
      icon: Icons.sailing_rounded,
    ),
    NovaAvatarPreset(
      id: 'vanta_bardo',
      label: 'Bardo',
      icon: Icons.history_edu_rounded,
    ),
    NovaAvatarPreset(
      id: 'vanta_pioneiro',
      label: 'Pioneiro',
      icon: Icons.rocket_launch_outlined,
    ),
  ];

  static NovaAvatarPreset getById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }
}

/// Widget de Renderização de Avatar Monocromático
class NovaAvatar extends StatelessWidget {
  final String avatarId;
  final double size;
  final VoidCallback? onTap;

  const NovaAvatar({
    super.key,
    required this.avatarId,
    this.size = 48.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preset = NovaAvatarPreset.getById(avatarId);

    final avatarWidget = Semantics(
      button: onTap != null,
      label: 'Avatar monocromático: ${preset.label}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: NovaColors.surfaceSecondary,
          shape: BoxShape.circle,
          border: Border.all(color: NovaColors.border, width: 1.5),
        ),
        child: Center(
          child: Icon(
            preset.icon,
            size: size * 0.55,
            color: NovaColors.textPrimary,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarWidget);
    }
    return avatarWidget;
  }
}
