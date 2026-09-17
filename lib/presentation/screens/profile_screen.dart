import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/vanta/vanta_config.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/user_profile.dart';
import '../../injection.dart';
import '../blocs/profile/profile_bloc.dart';
import '../blocs/profile/profile_event.dart';
import '../blocs/profile/profile_state.dart';
import '../design_system/nova_avatar.dart';
import '../design_system/nova_button.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_states.dart';

/// Tela Principal de Perfil, Estatísticas e Armazenamento (Fase M)
class ProfileScreen extends StatelessWidget {
  final ProfileBloc? bloc;

  const ProfileScreen({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    if (bloc != null) {
      return BlocProvider<ProfileBloc>.value(
        value: bloc!,
        child: const _ProfileScreenView(),
      );
    }

    return BlocProvider<ProfileBloc>(
      create: (_) => getIt<ProfileBloc>()..add(const LoadProfileEvent()),
      child: const _ProfileScreenView(),
    );
  }
}

class _ProfileScreenView extends StatelessWidget {
  const _ProfileScreenView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil & Preferências'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar Estatísticas',
            onPressed: () {
              context.read<ProfileBloc>().add(const RefreshStatsEvent());
            },
          ),
        ],
      ),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state is ProfileLoaded && state.feedbackMessage != null) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.feedbackMessage!,
                  style: NovaTypography.bodyMedium.copyWith(
                    color: NovaColors.textPrimary,
                  ),
                ),
                backgroundColor: NovaColors.surfaceSecondary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaShapes.radiusSm),
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const NovaLoadingState(
              message: 'Carregando perfil e estatísticas...',
            );
          }

          if (state is ProfileError) {
            return NovaErrorState(
              message: state.message,
              onRetry: () =>
                  context.read<ProfileBloc>().add(const LoadProfileEvent()),
            );
          }

          if (state is ProfileLoaded) {
            return SingleChildScrollView(
              padding: NovaSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: NovaSpacing.sm),

                  // 1. Cabeçalho com Avatar Monocromático e Edição de Nome
                  _buildHeaderSection(context, state),
                  const SizedBox(height: NovaSpacing.xl),

                  // 2. Painel de Estatísticas de Leitura (6 Métricas Consolidadas)
                  _buildSectionHeader('ESTATÍSTICAS DE LEITURA'),
                  const SizedBox(height: NovaSpacing.sm),
                  _buildReadingStatsCard(state.stats),
                  const SizedBox(height: NovaSpacing.xl),

                  // 3. Preferências de Leitura e Download
                  _buildSectionHeader('PREFERÊNCIAS DO LEITOR'),
                  const SizedBox(height: NovaSpacing.sm),
                  _buildPreferencesCard(context, state.profile),
                  const SizedBox(height: NovaSpacing.xl),

                  // 4. Gerenciamento de Armazenamento do Dispositivo
                  _buildSectionHeader('ARMAZENAMENTO DO DISPOSITIVO'),
                  const SizedBox(height: NovaSpacing.sm),
                  _buildStorageCard(context, state),
                  const SizedBox(height: NovaSpacing.xxl),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: NovaTypography.caption),
    );
  }

  Widget _buildHeaderSection(BuildContext context, ProfileLoaded state) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              NovaAvatar(
                avatarId: state.profile.avatarId,
                size: 96.0,
                onTap: () => _showAvatarModal(context, state.profile.avatarId),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () =>
                      _showAvatarModal(context, state.profile.avatarId),
                  child: Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: NovaColors.surfaceSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NovaColors.textPrimary,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      size: 16,
                      color: NovaColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.profile.name, style: NovaTypography.displayMedium),
              const SizedBox(width: NovaSpacing.xs),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: NovaColors.textSecondary,
                ),
                tooltip: 'Editar Nome',
                onPressed: () =>
                    _showEditNameDialog(context, state.profile.name),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.xxs),
          Text('Perfil Local • Modo Offline', style: NovaTypography.bodySmall),
          const SizedBox(height: NovaSpacing.sm),
          NovaButton(
            text: 'Trocar Avatar',
            icon: Icons.palette_outlined,
            variant: NovaButtonVariant.secondary,
            onPressed: () => _showAvatarModal(context, state.profile.avatarId),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingStatsCard(ReadingStats stats) {
    return NovaCard(
      padding: NovaSpacing.cardPadding,
      child: Column(
        children: [
          _buildStatRow(
            Icons.menu_book_rounded,
            'Livros Lidos',
            '${stats.booksRead}',
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStatRow(
            Icons.dashboard_customize_rounded,
            'HQs Lidas',
            '${stats.comicsRead}',
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStatRow(
            Icons.timelapse_rounded,
            'Em Andamento',
            '${stats.currentlyReading}',
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStatRow(
            Icons.favorite_outline_rounded,
            'Favoritos',
            '${stats.totalFavorites}',
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStatRow(
            Icons.download_done_rounded,
            'Obras Baixadas',
            '${stats.totalDownloaded}',
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStatRow(
            Icons.auto_stories_outlined,
            'Páginas Lidas',
            '${stats.totalPagesRead}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: NovaColors.accent),
        const SizedBox(width: NovaSpacing.md),
        Expanded(child: Text(label, style: NovaTypography.bodyMedium)),
        Text(value, style: NovaTypography.titleMedium),
      ],
    );
  }

  Widget _buildPreferencesCard(BuildContext context, UserProfile profile) {
    return NovaCard(
      padding: NovaSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tamanho de Fonte Padrão
          Text(
            'Tamanho de Fonte do Leitor',
            style: NovaTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: [14.0, 16.0, 18.0, 20.0].map((size) {
              final isSelected = profile.fontSize == size;
              return ChoiceChip(
                label: Text('${size.toInt()} pt'),
                selected: isSelected,
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    UpdatePreferencesEvent(fontSize: size),
                  );
                },
              );
            }).toList(),
          ),
          const Divider(height: NovaSpacing.xl, color: NovaColors.border),

          // 2. Modo de Leitura Padrão
          Text(
            'Modo de Leitura Padrão',
            style: NovaTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('Paginado'),
                selected: profile.readingMode == 'paged',
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: profile.readingMode == 'paged'
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: profile.readingMode == 'paged'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    const UpdatePreferencesEvent(readingMode: 'paged'),
                  );
                },
              ),
              ChoiceChip(
                label: const Text('Contínuo / Vertical'),
                selected: profile.readingMode == 'continuous',
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: profile.readingMode == 'continuous'
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: profile.readingMode == 'continuous'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    const UpdatePreferencesEvent(readingMode: 'continuous'),
                  );
                },
              ),
            ],
          ),
          const Divider(height: NovaSpacing.xl, color: NovaColors.border),

          // 3. Idioma Preferencial
          Text(
            'Idioma de Descoberta',
            style: NovaTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('Português (pt-BR)'),
                selected: profile.preferredLanguage == 'pt-BR',
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: profile.preferredLanguage == 'pt-BR'
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: profile.preferredLanguage == 'pt-BR'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    const UpdatePreferencesEvent(preferredLanguage: 'pt-BR'),
                  );
                },
              ),
              ChoiceChip(
                label: const Text('English (en)'),
                selected: profile.preferredLanguage == 'en',
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: profile.preferredLanguage == 'en'
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: profile.preferredLanguage == 'en'
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    const UpdatePreferencesEvent(preferredLanguage: 'en'),
                  );
                },
              ),
            ],
          ),
          const Divider(height: NovaSpacing.xl, color: NovaColors.border),

          // 4. Downloads Simultâneos
          Text(
            'Downloads Concorrentes Máximos',
            style: NovaTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: [1, 2, 3, 4].map((max) {
              final isSelected = profile.maxConcurrentDownloads == max;
              return ChoiceChip(
                label: Text('$max task${max > 1 ? 's' : ''}'),
                selected: isSelected,
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    UpdatePreferencesEvent(maxConcurrentDownloads: max),
                  );
                },
              );
            }).toList(),
          ),
          const Divider(height: NovaSpacing.xl, color: NovaColors.border),

          // 5. Cor Secundária / Aparência (G-07: paleta desaturada,
          // aplicada ao reabrir o app).
          Text(
            'Cor Secundária (Aparência)',
            style: NovaTypography.titleMedium.copyWith(fontSize: 14),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: VantaAccent.presets.map((accent) {
              final isSelected = profile.accentColor == accent.id;
              return ChoiceChip(
                avatar: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent.color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(accent.label),
                selected: isSelected,
                selectedColor: NovaColors.textPrimary,
                backgroundColor: NovaColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? NovaColors.background
                      : NovaColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  context.read<ProfileBloc>().add(
                    UpdatePreferencesEvent(accentColor: accent.id),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cor salva. Será aplicada ao reabrir o app.',
                      ),
                      duration: Duration(seconds: 2),
                      backgroundColor: NovaColors.surfaceSecondary,
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const Divider(height: NovaSpacing.xl, color: NovaColors.border),

          // 6. Gateway do Catálogo / API própria (vale de imediato).
          // No aparelho físico, `10.0.2.2` não roteia: use
          // `http://127.0.0.1:PORTA` com `adb reverse`, ou o IP da LAN.
          const _GatewayField(),
        ],
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, ProfileLoaded state) {
    final usage = state.storageUsage;

    return NovaCard(
      padding: NovaSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStorageDetailRow(
            'Livros Baixados',
            usage.formatBytes(usage.booksBytes),
          ),
          const SizedBox(height: NovaSpacing.xs),
          _buildStorageDetailRow(
            'Quadrinhos & HQs',
            usage.formatBytes(usage.comicsBytes),
          ),
          const SizedBox(height: NovaSpacing.xs),
          _buildStorageDetailRow(
            'Capas e Miniaturas',
            usage.formatBytes(usage.coversBytes + usage.thumbnailsBytes),
          ),
          const SizedBox(height: NovaSpacing.xs),
          _buildStorageDetailRow(
            'Banco de Dados Local',
            usage.formatBytes(usage.databaseBytes),
          ),
          const SizedBox(height: NovaSpacing.xs),
          _buildStorageDetailRow(
            'Cache Volátil de Streaming',
            usage.formatBytes(usage.cacheBytes),
          ),
          const Divider(height: NovaSpacing.lg, color: NovaColors.border),
          _buildStorageDetailRow(
            'Total Ocupado',
            usage.formatBytes(usage.totalBytes),
            isBold: true,
          ),
          const SizedBox(height: NovaSpacing.lg),

          // Botões de Limpeza Segura
          if (state.isClearingCache)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: NovaSpacing.sm),
                child: CircularProgressIndicator(
                  color: NovaColors.textPrimary,
                  strokeWidth: 2,
                ),
              ),
            )
          else ...[
            NovaButton(
              text: 'Limpar Cache de Streaming',
              icon: Icons.cleaning_services_rounded,
              variant: NovaButtonVariant.secondary,
              isFullWidth: true,
              onPressed: () {
                context.read<ProfileBloc>().add(
                  const ClearCacheEvent(readingCacheOnly: true),
                );
              },
            ),
            const SizedBox(height: NovaSpacing.xs),
            NovaButton(
              text: 'Limpar Todo o Cache',
              icon: Icons.delete_sweep_rounded,
              variant: NovaButtonVariant.ghost,
              isFullWidth: true,
              onPressed: () => _confirmClearAllCache(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageDetailRow(
    String label,
    String size, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: isBold
                ? NovaTypography.titleMedium
                : NovaTypography.bodyMedium,
          ),
        ),
        const SizedBox(width: NovaSpacing.xs),
        Text(
          size,
          style: isBold
              ? NovaTypography.titleMedium.copyWith(
                  color: NovaColors.textPrimary,
                )
              : NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textSecondary,
                ),
        ),
      ],
    );
  }

  void _showAvatarModal(BuildContext context, String currentAvatarId) {
    final bloc = context.read<ProfileBloc>();

    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaShapes.radiusLg),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: NovaSpacing.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CATÁLOGO DE AVATARES MONOCROMÁTICOS',
                style: NovaTypography.caption,
              ),
              const SizedBox(height: NovaSpacing.md),
              Wrap(
                spacing: NovaSpacing.md,
                runSpacing: NovaSpacing.md,
                children: NovaAvatarPreset.presets.map((preset) {
                  final isSelected = preset.id == currentAvatarId;
                  return Tooltip(
                    message: preset.label,
                    child: GestureDetector(
                      onTap: () {
                        bloc.add(UpdateAvatarEvent(preset.id));
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? NovaColors.textPrimary
                                : Colors.transparent,
                            width: 2.0,
                          ),
                        ),
                        padding: const EdgeInsets.all(2.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            NovaAvatar(avatarId: preset.id, size: 56.0),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: NovaSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final textController = TextEditingController(text: currentName);
    final bloc = context.read<ProfileBloc>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: NovaColors.surface,
          title: Text('Alterar Nome', style: NovaTypography.titleMedium),
          content: TextField(
            controller: textController,
            autofocus: true,
            style: NovaTypography.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Seu nome ou apelido',
              hintStyle: NovaTypography.bodySmall,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NovaColors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: NovaColors.textPrimary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR', style: NovaTypography.bodySmall),
            ),
            TextButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  bloc.add(UpdateProfileNameEvent(text));
                }
                Navigator.pop(ctx);
              },
              child: Text(
                'SALVAR',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearAllCache(BuildContext context) {
    final bloc = context.read<ProfileBloc>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: NovaColors.surface,
          title: Text(
            'Limpar Todo o Cache?',
            style: NovaTypography.titleMedium,
          ),
          content: Text(
            'Isso limpará todos os arquivos voláteis de leitura e temporários. Seus livros, quadrinhos e capas permanentes continuarão 100% seguros.',
            style: NovaTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR', style: NovaTypography.bodySmall),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                bloc.add(const ClearCacheEvent(readingCacheOnly: false));
              },
              child: Text(
                'LIMPAR',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Campo de configuração do gateway da API própria (VANTA Catalog).
/// Salva em `settings` e aplica de imediato, sem rebuild.
class _GatewayField extends StatefulWidget {
  const _GatewayField();

  @override
  State<_GatewayField> createState() => _GatewayFieldState();
}

class _GatewayFieldState extends State<_GatewayField> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: const VantaConfig().effectiveBaseUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = getIt<AppDatabase>();
      await VantaConfig.persist(db, _controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gateway salvo: ${const VantaConfig().effectiveBaseUrl}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: NovaColors.surfaceSecondary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gateway do Catálogo (API própria)',
          style: NovaTypography.titleMedium.copyWith(fontSize: 14),
        ),
        const SizedBox(height: NovaSpacing.xs),
        Text(
          'Vazio = padrão do build. No aparelho físico use '
          'http://127.0.0.1:PORTA com adb reverse.',
          style: NovaTypography.caption,
        ),
        const SizedBox(height: NovaSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: NovaTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: VantaConfig.defaultBaseUrl,
                  hintStyle: NovaTypography.bodySmall,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: NovaColors.border),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: NovaColors.textPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: NovaSpacing.sm),
            _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : TextButton(
                    onPressed: _save,
                    child: Text(
                      'APLICAR',
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ],
    );
  }
}
