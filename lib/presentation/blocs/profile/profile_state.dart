import 'package:equatable/equatable.dart';
import '../../../core/storage/storage_manager.dart';
import '../../../domain/entities/user_profile.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  final UserProfile profile;
  final ReadingStats stats;
  final StorageUsage storageUsage;
  final bool isClearingCache;
  final String? feedbackMessage;

  const ProfileLoaded({
    required this.profile,
    required this.stats,
    required this.storageUsage,
    this.isClearingCache = false,
    this.feedbackMessage,
  });

  ProfileLoaded copyWith({
    UserProfile? profile,
    ReadingStats? stats,
    StorageUsage? storageUsage,
    bool? isClearingCache,
    String? feedbackMessage,
  }) {
    return ProfileLoaded(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      storageUsage: storageUsage ?? this.storageUsage,
      isClearingCache: isClearingCache ?? this.isClearingCache,
      feedbackMessage: feedbackMessage,
    );
  }

  @override
  List<Object?> get props => [
    profile,
    stats,
    storageUsage,
    isClearingCache,
    feedbackMessage,
  ];
}

class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
