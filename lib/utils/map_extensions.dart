// lib/utils/map_extensions.dart

extension MapExtensions on Map<String, dynamic>? {
  String get username => this?['username'] ?? 'Anonymous';
  String get email => this?['email'] ?? '';
  String get bio => this?['bio'] ?? '';
  int get reelsCount => this?['reelsCount'] ?? 0;
  int get followersCount => this?['followersCount'] ?? 0;
  int get followingCount => this?['followingCount'] ?? 0;
  List<String> get savedReels => List<String>.from(this?['savedReels'] ?? []);

  Map<String, dynamic> get languagePreferences =>
      this?['languagePreferences'] ??
      {
        'primaryLanguage': 'en',
        'learningLanguages': ['es', 'fr'],
        'proficiencyLevels': {'es': 'beginner', 'fr': 'beginner'},
      };
}
