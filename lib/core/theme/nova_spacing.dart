import 'package:flutter/material.dart';

/// Tokens de Espaçamento Canônicos do NovaReader
class NovaSpacing {
  NovaSpacing._();

  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Insets comuns
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets pagePaddingTablet = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets compactCardPadding = EdgeInsets.all(sm);
}

/// Tokens de Formas e Bordas Canônicas do NovaReader
class NovaShapes {
  NovaShapes._();

  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;

  static final BorderRadius roundedSm = BorderRadius.circular(radiusSm);
  static final BorderRadius roundedMd = BorderRadius.circular(radiusMd);
  static final BorderRadius roundedLg = BorderRadius.circular(radiusLg);
  static final BorderRadius pill = BorderRadius.circular(radiusFull);

  static const double borderWidth = 1.0;
  static const double borderWidthThick = 2.0;
}
