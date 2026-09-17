import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadProfileEvent extends ProfileEvent {
  const LoadProfileEvent();
}

class UpdateProfileNameEvent extends ProfileEvent {
  final String newName;
  const UpdateProfileNameEvent(this.newName);

  @override
  List<Object?> get props => [newName];
}

class UpdateAvatarEvent extends ProfileEvent {
  final String avatarId;
  const UpdateAvatarEvent(this.avatarId);

  @override
  List<Object?> get props => [avatarId];
}

class UpdatePreferencesEvent extends ProfileEvent {
  final double? fontSize;
  final String? fontFamily;
  final String? readingMode;
  final int? maxConcurrentDownloads;
  final String? preferredLanguage;
  final String? accentColor;

  const UpdatePreferencesEvent({
    this.fontSize,
    this.fontFamily,
    this.readingMode,
    this.maxConcurrentDownloads,
    this.preferredLanguage,
    this.accentColor,
  });

  @override
  List<Object?> get props => [
    fontSize,
    fontFamily,
    readingMode,
    maxConcurrentDownloads,
    preferredLanguage,
    accentColor,
  ];
}

class RefreshStatsEvent extends ProfileEvent {
  const RefreshStatsEvent();
}

class LoadStorageUsageEvent extends ProfileEvent {
  const LoadStorageUsageEvent();
}

class ClearCacheEvent extends ProfileEvent {
  final bool readingCacheOnly;
  const ClearCacheEvent({this.readingCacheOnly = false});

  @override
  List<Object?> get props => [readingCacheOnly];
}
