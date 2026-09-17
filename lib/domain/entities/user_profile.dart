import 'package:equatable/equatable.dart';

/// Perfil Local e Preferências Pessoais do Usuário (Fase M)
class UserProfile extends Equatable {
  final String id;
  final String name;
  final String avatarId;
  final String preferredLanguage; // 'pt-BR' ou 'en'
  final double fontSize;
  final String fontFamily;
  final String readingMode; // 'paged' ou 'continuous'
  final int maxConcurrentDownloads;
  final String accentColor; // id de `VantaAccent.presets` ('grafite' padrão)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    this.preferredLanguage = 'pt-BR',
    this.fontSize = 16.0,
    this.fontFamily = 'Inter',
    this.readingMode = 'paged',
    this.maxConcurrentDownloads = 2,
    this.accentColor = 'grafite',
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? name,
    String? avatarId,
    String? preferredLanguage,
    double? fontSize,
    String? fontFamily,
    String? readingMode,
    int? maxConcurrentDownloads,
    String? accentColor,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      readingMode: readingMode ?? this.readingMode,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
      accentColor: accentColor ?? this.accentColor,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    avatarId,
    preferredLanguage,
    fontSize,
    fontFamily,
    readingMode,
    maxConcurrentDownloads,
    accentColor,
  ];
}

/// Estatísticas Consolidadas de Leitura do Usuário
class ReadingStats extends Equatable {
  final int booksRead;
  final int comicsRead;
  final int currentlyReading;
  final int totalFavorites;
  final int totalDownloaded;
  final int totalPagesRead;

  const ReadingStats({
    this.booksRead = 0,
    this.comicsRead = 0,
    this.currentlyReading = 0,
    this.totalFavorites = 0,
    this.totalDownloaded = 0,
    this.totalPagesRead = 0,
  });

  @override
  List<Object?> get props => [
    booksRead,
    comicsRead,
    currentlyReading,
    totalFavorites,
    totalDownloaded,
    totalPagesRead,
  ];
}
