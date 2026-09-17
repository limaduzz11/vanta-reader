import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/nova_colors.dart';
import '../screens/downloads_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../screens/splash_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Configuração Canônica de Rotas e Navegação Adaptativa do VANTA Reader
class AppRouter {
  AppRouter._();

  static GoRouter createRouter({String initialLocation = '/home'}) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AdaptiveShellScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => const SearchScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const LibraryScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/downloads',
                  builder: (context, state) => const DownloadsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static final GoRouter router = createRouter();
}

/// Shell Adaptativo que alterna entre BottomNavigationBar (Mobile) e NavigationRail (Tablet)
class AdaptiveShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 720;

        if (isTablet) {
          // Layout Tablet com Navigation Rail lateral
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) => _onTap(index),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: NovaColors.textPrimary,
                      size: 28,
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Início'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search_rounded),
                      label: Text('Busca'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.local_library_outlined),
                      selectedIcon: Icon(Icons.local_library_rounded),
                      label: Text('Biblioteca'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.download_outlined),
                      selectedIcon: Icon(Icons.download_rounded),
                      label: Text('Downloads'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Perfil'),
                    ),
                  ],
                ),
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: NovaColors.border,
                ),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        // Layout Celular com BottomNavigationBar
        return Scaffold(
          body: navigationShell,
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => _onTap(index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Início',
                tooltip: 'Aba Início',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search_rounded),
                label: 'Busca',
                tooltip: 'Aba Busca',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_library_outlined),
                activeIcon: Icon(Icons.local_library_rounded),
                label: 'Biblioteca',
                tooltip: 'Aba Biblioteca',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.download_outlined),
                activeIcon: Icon(Icons.download_rounded),
                label: 'Downloads',
                tooltip: 'Aba Downloads',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Perfil',
                tooltip: 'Aba Perfil',
              ),
            ],
          ),
        );
      },
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
