// 2. Now let's create safe accessors for the user profile
// lib/utils/user_profile_extensions.dart

extension UserProfileExtensions on Map<String, dynamic>? {
  String get username => this?['username'] ?? 'Anonymous';
  String get email => this?['email'] ?? '';
  String get bio => this?['bio'] ?? '';
  int get reelsCount => (this?['reelsCount'] as int?) ?? 0;
  int get followersCount => (this?['followersCount'] as int?) ?? 0;
  int get followingCount => (this?['followingCount'] as int?) ?? 0;
  List<String> get savedReels => List<String>.from(this?['savedReels'] ?? []);

  Map<String, dynamic> get languagePreferences =>
      Map<String, dynamic>.from(this?['languagePreferences'] ??
          {
            'primaryLanguage': 'en',
            'learningLanguages': ['es', 'fr'],
            'proficiencyLevels': {'es': 'beginner', 'fr': 'beginner'},
          });
}
