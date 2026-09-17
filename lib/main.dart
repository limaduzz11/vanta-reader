import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'core/providers/vanta/vanta_config.dart';
import 'core/theme/nova_colors.dart';
import 'core/theme/nova_theme.dart';
import 'domain/repositories/i_profile_repository.dart';
import 'injection.dart';
import 'presentation/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa injeção de dependências, banco SQLite e storage
  await setupInjection();

  // Gateway do catálogo configurado em runtime (Perfil > Gateway).
  try {
    if (getIt.isRegistered<AppDatabase>()) {
      await VantaConfig.loadPersisted(getIt<AppDatabase>());
    }
  } catch (_) {}

  // G-07: acento secundário persistido (aplicado ao abrir; troca reflete
  // no próximo start). Falha de leitura cai no tema padrão.
  Color accent = NovaColors.accent;
  try {
    if (getIt.isRegistered<IProfileRepository>()) {
      final profile = await getIt<IProfileRepository>().getProfile();
      accent = VantaAccent.getById(profile.accentColor).color;
    }
  } catch (_) {}

  runApp(VantaReaderApp(accentColor: accent));
}

/// Ponto de Entrada da Aplicação VANTA Reader
class VantaReaderApp extends StatelessWidget {
  final String initialLocation;
  final Color accentColor;
  const VantaReaderApp({
    super.key,
    this.initialLocation = '/home',
    this.accentColor = NovaColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VANTA Reader',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.darkThemeWithAccent(accentColor),
      routerConfig: initialLocation == '/home'
          ? AppRouter.router
          : AppRouter.createRouter(initialLocation: initialLocation),
    );
  }
}

/// Alias para retrocompatibilidade
typedef NovaReaderApp = VantaReaderApp;
