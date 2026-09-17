/// Tokens de Dimensões e Elevações Canônicos do NovaReader
class NovaDimensions {
  NovaDimensions._();

  // Proporções de Capas
  static const double bookCoverAspectRatio = 2.0 / 3.0; // 2:3 padrão editorial
  static const double comicCoverAspectRatio =
      3.0 / 4.0; // 3:4 padrão quadrinhos / graphic novels

  // Larguras Mínimas de Cards em Grids
  static const double bookCardMinWidth = 120.0;
  static const double bookCardMaxWidth = 180.0;
  static const double comicCardMinWidth = 140.0;
  static const double comicCardMaxWidth = 220.0;

  // Alturas de Carrosséis na Home
  static const double homeCarouselHeight = 265.0;
  static const double homeComicCarouselHeight = 285.0;

  // Proporção de Cards em Grid (Largura / Altura)
  static const double gridCardAspectRatio = 0.50;

  // Breakpoints de Responsividade
  static const double mobileBreakpoint = 720.0;
  static const double desktopBreakpoint = 1200.0;

  // Alturas Padrão
  static const double appBarHeight = 56.0;
  static const double bottomNavHeight = 64.0;
  static const double navigationRailWidth = 72.0;
  static const double searchBarHeight = 48.0;
  static const double buttonHeight = 44.0;
  static const double compactButtonHeight = 36.0;
}

/// Elevações e Sombras
class NovaElevation {
  NovaElevation._();

  static const double level0 = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 3.0;
  static const double level3 = 6.0;
  static const double level4 = 8.0;
}
