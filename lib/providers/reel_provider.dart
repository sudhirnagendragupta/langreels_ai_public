// lib/providers/reel_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth; // ADD 'as firebase_auth'
import '../models/ai_language_reel.dart';
import '../services/firebase_service.dart';
import '../constants/app_constants.dart';
import 'auth_provider.dart';

enum ReelLoadingState { initial, loading, loaded, empty, error }

class ReelProvider with ChangeNotifier {
  AuthProvider? _authProvider;

  // Data state
  List<AILanguageReel> _homeReels = [];
  List<AILanguageReel> _userReels = [];
  List<AILanguageReel> _savedReels = [];
  List<AILanguageReel> _searchResults = [];
  Map<String, List<ReelComment>> _comments = {};

  // Loading states
  ReelLoadingState _homeLoadingState = ReelLoadingState.initial;
  ReelLoadingState _userLoadingState = ReelLoadingState.initial;
  ReelLoadingState _savedLoadingState = ReelLoadingState.initial;
  bool _isLoadingMore = false;
  bool _hasMoreReels = true;
  String? _errorMessage;

  // Filter state
  List<String> _selectedLanguages = ['all'];
  String _searchQuery = '';

  List<AILanguageReel> _likedReels = [];
  ReelLoadingState _likedLoadingState = ReelLoadingState.initial;
  StreamSubscription<List<AILanguageReel>>? _likedReelsSubscription;

  List<AILanguageReel> get likedReels => _likedReels;
  ReelLoadingState get likedLoadingState => _likedLoadingState;

  // Stream subscriptions
  StreamSubscription<List<AILanguageReel>>? _homeReelsSubscription;
  StreamSubscription<List<AILanguageReel>>? _userReelsSubscription;
  StreamSubscription<List<AILanguageReel>>? _savedReelsSubscription;

  // Track if we've attempted to load data
  bool _hasAttemptedLoad = false;

  // Getters
  List<AILanguageReel> get homeReels => _homeReels;
  List<AILanguageReel> get userReels => _userReels;
  List<AILanguageReel> get savedReels => _savedReels;
  List<AILanguageReel> get searchResults => _searchResults;
  Map<String, List<ReelComment>> get comments => _comments;

  ReelLoadingState get homeLoadingState {
    // If we have an authenticated user but haven't attempted to load yet, show loading
    if (_authProvider?.isAuthenticated == true && !_hasAttemptedLoad) {
      return ReelLoadingState.loading;
    }
    return _homeLoadingState;
  }

  ReelLoadingState get userLoadingState => _userLoadingState;
  ReelLoadingState get savedLoadingState => _savedLoadingState;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreReels => _hasMoreReels;
  String? get errorMessage => _errorMessage;

  List<String> get selectedLanguages => _selectedLanguages;
  String get searchQuery => _searchQuery;

  // Backward compatibility getters
  bool get isLoading => homeLoadingState == ReelLoadingState.loading;
  bool get isFiltering =>
      homeLoadingState == ReelLoadingState.loading && _homeReels.isNotEmpty;
  String get languageFilter =>
      _selectedLanguages.contains('all') ? 'all' : _selectedLanguages.first;

  @override
  void dispose() {
    _homeReelsSubscription?.cancel();
    _userReelsSubscription?.cancel();
    _savedReelsSubscription?.cancel();
    _likedReelsSubscription?.cancel(); // Add this
    super.dispose();
  }

  void _cancelAllSubscriptions() {
    _homeReelsSubscription?.cancel();
    _userReelsSubscription?.cancel();
    _savedReelsSubscription?.cancel();
  }

  // Load liked reels
  void loadLikedReels(String userId) {
    _startLikedReelsStream(userId);
  }

  void _startLikedReelsStream(String userId) {
    _likedLoadingState = ReelLoadingState.loading;
    notifyListeners();

    _likedReelsSubscription?.cancel();
    _likedReelsSubscription =
        FirebaseService.getLikedReelsStream(userId).listen(
      (reels) {
        _likedReels = reels;
        _likedLoadingState =
            reels.isEmpty ? ReelLoadingState.empty : ReelLoadingState.loaded;
        notifyListeners();
      },
      onError: (error) {
        _likedLoadingState = ReelLoadingState.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void updateAuth(AuthProvider authProvider) {
    final wasAuthenticated = _authProvider?.isAuthenticated ?? false;
    final isNowAuthenticated = authProvider.isAuthenticated;

    // Check if user ID actually changed (prevents redundant calls during profile updates)
    final userIdChanged = _authProvider?.userId != authProvider.userId;

    _authProvider = authProvider;

    // Only initialize streams when authentication state ACTUALLY changes
    // or when user ID changes (account switch)
    if (!wasAuthenticated && isNowAuthenticated) {
      // User just signed in
      // print('🔐 User authenticated - initializing streams');
      _initializeDataStreams();
    } else if (wasAuthenticated && !isNowAuthenticated) {
      // User just signed out
      // print('🚪 User signed out - clearing data');
      _clearAllData();
    } else if (wasAuthenticated && isNowAuthenticated && userIdChanged) {
      // User switched accounts
      // print('🔄 User switched accounts - reinitializing');
      _clearAllData();
      _hasAttemptedLoad = false;
      _initializeDataStreams();
    } else {
      // Just a profile update, no action needed
      // print('⏭️ Profile update - no stream action needed');
    }

    notifyListeners();
  }

  void _initializeDataStreams() {
    if (_authProvider?.isAuthenticated != true) return;
    if (_hasAttemptedLoad) return;

    _hasAttemptedLoad = true;
    _waitForAuthThenLoadData();
  }

  // Replace the _waitForAuthThenLoadData method in reel_provider.dart

  Future<void> _waitForAuthThenLoadData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _homeLoadingState = ReelLoadingState.error;
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return;
    }

    // Start loading data immediately
    // The Firestore rules now allow reading /translations collection
    _startHomeReelsStream();

    final userId = _authProvider?.userId;
    if (userId != null) {
      _startUserReelsStream(userId);
      _startSavedReelsStream(userId);
    }
  }

  void _startHomeReelsStream() {
    // Prevent duplicate stream creation if already loading or loaded
    if (_homeLoadingState == ReelLoadingState.loading &&
        _homeReelsSubscription != null) {
      // print('⏭️ SKIP: Stream already active');
      return;
    }

    // print('🔄 STARTING: Creating new stream subscription');

    _homeLoadingState = ReelLoadingState.loading;
    notifyListeners();

    _homeReelsSubscription?.cancel();

    try {
      _homeReelsSubscription =
          FirebaseService.getProcessedReelsStreamWithLanguages(
        limit: AppConstants.reelsPerPage,
        languageFilters:
            _selectedLanguages.contains('all') ? null : _selectedLanguages,
        populateSentences: true,
      ).listen(
        (reels) {
          // print('✅ SUCCESS: Received ${reels.length} reels');
          _homeReels = reels;
          _homeLoadingState =
              reels.isEmpty ? ReelLoadingState.empty : ReelLoadingState.loaded;
          _hasMoreReels = reels.length >= AppConstants.reelsPerPage;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          // print('❌ ERROR: $error');
          _homeLoadingState = ReelLoadingState.error;
          _errorMessage = error.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      // print('❌ EXCEPTION: $e');
      _homeLoadingState = ReelLoadingState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void _startUserReelsStream(String userId) {
    _userLoadingState = ReelLoadingState.loading;
    notifyListeners();

    _userReelsSubscription?.cancel();
    _userReelsSubscription = FirebaseService.getUserReelsStreamWithSentences(
      userId,
      limit: AppConstants.reelsPerPage,
    ).listen(
      (reels) {
        _userReels = reels;
        _userLoadingState =
            reels.isEmpty ? ReelLoadingState.empty : ReelLoadingState.loaded;
        notifyListeners();
      },
      onError: (error) {
        _userLoadingState = ReelLoadingState.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void _startSavedReelsStream(String userId) {
    _savedLoadingState = ReelLoadingState.loading;
    notifyListeners();

    _savedReelsSubscription?.cancel();
    _savedReelsSubscription =
        FirebaseService.getSavedReelsStream(userId).listen(
      (reels) {
        _savedReels = reels;
        _savedLoadingState =
            reels.isEmpty ? ReelLoadingState.empty : ReelLoadingState.loaded;
        notifyListeners();
      },
      onError: (error) {
        _savedLoadingState = ReelLoadingState.error;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  void _clearAllData() {
    _cancelAllSubscriptions();

    _homeReels.clear();
    _userReels.clear();
    _savedReels.clear();
    _searchResults.clear();
    _comments.clear();

    _homeLoadingState = ReelLoadingState.initial;
    _userLoadingState = ReelLoadingState.initial;
    _savedLoadingState = ReelLoadingState.initial;

    _hasAttemptedLoad = false;
    _errorMessage = null;
    _selectedLanguages = ['all'];
    _searchQuery = '';

    notifyListeners();
  }

  // Public methods that can be called from UI
  Future<void> loadHomeReels({bool refresh = false}) async {
    if (_authProvider?.isAuthenticated != true) return;

    if (refresh) {
      _hasMoreReels = true;
      _hasAttemptedLoad = true;
      _startHomeReelsStream();
    } else if (!_hasAttemptedLoad) {
      _initializeDataStreams();
    }
  }

  Future<void> loadUserReels(String userId) async {
    if (_authProvider?.isAuthenticated != true) return;
    _startUserReelsStream(userId);
  }

  Future<void> loadSavedReels(String userId) async {
    if (_authProvider?.isAuthenticated != true) return;
    _startSavedReelsStream(userId);
  }

  // Language filtering
  void setSelectedLanguages(List<String> languages) {
    _selectedLanguages = languages.isEmpty ? ['all'] : languages;

    if (_selectedLanguages.contains('all') && _selectedLanguages.length > 1) {
      _selectedLanguages.remove('all');
    }

    if (_selectedLanguages.isEmpty) {
      _selectedLanguages = ['all'];
    }

    // Restart home stream with new filters
    if (_authProvider?.isAuthenticated == true && _hasAttemptedLoad) {
      _startHomeReelsStream();
    }
  }

  void setLanguageFilter(String language) {
    setSelectedLanguages([language]);
  }

  void toggleLanguageSelection(String languageCode) {
    List<String> newSelection = List<String>.from(_selectedLanguages);

    if (languageCode == 'all') {
      newSelection = ['all'];
    } else {
      newSelection.remove('all');

      if (newSelection.contains(languageCode)) {
        newSelection.remove(languageCode);
      } else {
        newSelection.add(languageCode);
      }

      if (newSelection.isEmpty) {
        newSelection = ['all'];
      }
    }

    setSelectedLanguages(newSelection);
  }

  void clearFilters() {
    setSelectedLanguages(['all']);
  }

  // Search functionality
  Future<void> searchReels(String query) async {
    if (_authProvider?.isAuthenticated != true) return;

    _searchQuery = query;

    if (query.isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }

    try {
      final results = await FirebaseService.searchReelsWithLanguages(
        query: query,
        sourceLanguages:
            _selectedLanguages.contains('all') ? null : _selectedLanguages,
      );

      _searchResults = results;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Social interactions
  Future<void> toggleLike(String reelId) async {
    if (_authProvider?.userId == null) return;

    try {
      await FirebaseService.toggleLike(reelId, _authProvider!.userId!);

      _updateReelInLists(reelId, (reel) {
        final likedBy = List<String>.from(reel.likedBy);
        if (likedBy.contains(_authProvider!.userId!)) {
          likedBy.remove(_authProvider!.userId!);
        } else {
          likedBy.add(_authProvider!.userId!);
        }
        return reel.copyWith(
          likedBy: likedBy,
          likes: likedBy.length,
        );
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleSave(String reelId) async {
    if (_authProvider?.userId == null) return;

    try {
      await FirebaseService.toggleSaveReel(reelId, _authProvider!.userId!);

      _updateReelInLists(reelId, (reel) {
        final savedBy = List<String>.from(reel.savedBy);
        if (savedBy.contains(_authProvider!.userId!)) {
          savedBy.remove(_authProvider!.userId!);
        } else {
          savedBy.add(_authProvider!.userId!);
        }
        return reel.copyWith(savedBy: savedBy);
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Comments
  Future<void> loadComments(String reelId) async {
    if (_authProvider?.isAuthenticated != true) return;

    try {
      FirebaseService.getCommentsStream(reelId).listen((comments) {
        _comments[reelId] = comments;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addComment(String reelId, String text) async {
    try {
      if (_authProvider == null || _authProvider!.userId == null) {
        _errorMessage = 'You must be logged in to comment';
        notifyListeners();
        return;
      }

      final username =
          _authProvider!.userProfile?['username'] as String? ?? 'User';
      final displayName =
          _authProvider!.userProfile?['displayName'] as String?; // NEW

      await FirebaseService.addComment(
        reelId: reelId,
        text: text,
        authorId: _authProvider!.userId!,
        authorName: username,
        authorDisplayName: displayName, // NEW: Pass display name
      );

      _updateReelInLists(reelId, (reel) {
        return reel.copyWith(comments: reel.comments + 1);
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Share functionality
  Future<void> shareReel(String reelId) async {
    try {
      await FirebaseService.shareReel(reelId);

      _updateReelInLists(reelId, (reel) {
        return reel.copyWith(shares: reel.shares + 1);
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Utility methods
  void addReelToTop(AILanguageReel reel) {
    _homeReels.removeWhere((existingReel) => existingReel.id == reel.id);
    _homeReels.insert(0, reel);

    if (_homeLoadingState == ReelLoadingState.empty) {
      _homeLoadingState = ReelLoadingState.loaded;
    }

    notifyListeners();
  }

  void removeReel(String reelId) {
    _homeReels.removeWhere((reel) => reel.id == reelId);
    _userReels.removeWhere((reel) => reel.id == reelId);
    _savedReels.removeWhere((reel) => reel.id == reelId);
    _searchResults.removeWhere((reel) => reel.id == reelId);

    // Update loading states if lists become empty
    if (_homeReels.isEmpty && _homeLoadingState == ReelLoadingState.loaded) {
      _homeLoadingState = ReelLoadingState.empty;
    }
    if (_userReels.isEmpty && _userLoadingState == ReelLoadingState.loaded) {
      _userLoadingState = ReelLoadingState.empty;
    }
    if (_savedReels.isEmpty && _savedLoadingState == ReelLoadingState.loaded) {
      _savedLoadingState = ReelLoadingState.empty;
    }

    notifyListeners();
  }

  Future<void> refreshReel(String reelId) async {
    try {
      final updatedReel =
          await FirebaseService.getReelByIdWithSentences(reelId);
      if (updatedReel == null) return;

      _updateReelInLists(reelId, (oldReel) => updatedReel);
      notifyListeners();
    } catch (e) {
      // Silently handle refresh errors
    }
  }

  AILanguageReel? getReelById(String reelId) {
    for (final reel in _homeReels) {
      if (reel.id == reelId) return reel;
    }
    for (final reel in _userReels) {
      if (reel.id == reelId) return reel;
    }
    for (final reel in _savedReels) {
      if (reel.id == reelId) return reel;
    }
    for (final reel in _searchResults) {
      if (reel.id == reelId) return reel;
    }
    return null;
  }

  List<AILanguageReel> getUserReels(String userId) {
    return _userReels.where((reel) => reel.authorId == userId).toList();
  }

  void _updateReelInLists(
      String reelId, AILanguageReel Function(AILanguageReel) updateFunction) {
    // Update in home reels
    for (int i = 0; i < _homeReels.length; i++) {
      if (_homeReels[i].id == reelId) {
        _homeReels[i] = updateFunction(_homeReels[i]);
        break;
      }
    }

    // Update in user reels
    for (int i = 0; i < _userReels.length; i++) {
      if (_userReels[i].id == reelId) {
        _userReels[i] = updateFunction(_userReels[i]);
        break;
      }
    }

    // Update in saved reels
    for (int i = 0; i < _savedReels.length; i++) {
      if (_savedReels[i].id == reelId) {
        _savedReels[i] = updateFunction(_savedReels[i]);
        break;
      }
    }

    // Update in search results
    for (int i = 0; i < _searchResults.length; i++) {
      if (_searchResults[i].id == reelId) {
        _searchResults[i] = updateFunction(_searchResults[i]);
        break;
      }
    }
  }
}
