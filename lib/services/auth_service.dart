import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final StreamController<UserModel?> _userStreamController =
      StreamController<UserModel?>.broadcast();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _userStreamController.stream;

  bool _isFirebaseAvailable = false;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  bool _isInitialAuthChecked = false;
  bool get isInitialAuthChecked => _isInitialAuthChecked;

  SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;

  // Active phone auth session
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  String? _pendingPhoneNumber;

  // Registered mock users cache (by id and formatted phone number)
  final Map<String, UserModel> _mockUsersById = {};
  final Map<String, UserModel> _mockUsersByPhone = {};

  void resetMockRegistryForTesting() {
    _mockUsersById.clear();
    _mockUsersByPhone.clear();
  }

  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    _isFirebaseAvailable = Firebase.apps.isNotEmpty;
    if (_isFirebaseAvailable) {
      try {
        // Check if there is an existing Firebase session on disk
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final cachedName = _prefs?.getString('user_name_${fbUser.uid}') ?? '';
          final cachedOrder = _prefs?.getStringList('user_group_order_${fbUser.uid}') ?? [];

          _currentUser = UserModel(
            id: fbUser.uid,
            name: cachedName.isNotEmpty
                ? cachedName
                : (fbUser.displayName ?? fbUser.phoneNumber ?? 'User'),
            phoneNumber: fbUser.phoneNumber ?? '',
            groupOrder: cachedOrder,
            createdAt: DateTime.now(),
          );
          _mockUsersById[_currentUser!.id] = _currentUser!;
          if (_currentUser!.phoneNumber.isNotEmpty) {
            _mockUsersByPhone[_currentUser!.phoneNumber] = _currentUser!;
          }
          _isInitialAuthChecked = true;
        }

        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
          _isInitialAuthChecked = true;
          if (user == null) {
            _currentUser = null;
            _userStreamController.add(null);
          } else {
            await _syncUserProfile(user);
          }
        });
      } catch (_) {
        _isFirebaseAvailable = false;
        _isInitialAuthChecked = true;
      }
    } else {
      _isInitialAuthChecked = true;
    }
  }

  Future<void> _syncUserProfile(User user, [String? optionalName]) async {
    final phone = user.phoneNumber ?? _pendingPhoneNumber ?? '';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));

      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromMap(user.uid, doc.data()!);
        _prefs ??= await SharedPreferences.getInstance();
        _prefs?.setString('user_name_${user.uid}', _currentUser!.name);
        
        final cachedOrder = _prefs?.getStringList('user_group_order_${user.uid}') ?? [];
        if (_currentUser!.groupOrder.isNotEmpty) {
          _prefs?.setStringList('user_group_order_${user.uid}', _currentUser!.groupOrder);
        } else if (cachedOrder.isNotEmpty) {
          _currentUser = _currentUser!.copyWith(groupOrder: cachedOrder);
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'groupOrder': cachedOrder}, SetOptions(merge: true));
        }
      } else {
        final name = optionalName?.trim().isNotEmpty == true
            ? optionalName!.trim()
            : (user.displayName ?? (phone.isNotEmpty ? phone : 'User'));

        final newUser = UserModel(
          id: user.uid,
          name: name,
          phoneNumber: phone,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(newUser.toMap())
            .timeout(const Duration(seconds: 3));

        _currentUser = newUser;
        _prefs ??= await SharedPreferences.getInstance();
        _prefs?.setString('user_name_${user.uid}', newUser.name);
      }
    } catch (_) {
      _currentUser = UserModel(
        id: user.uid,
        name: optionalName ?? user.displayName ?? (phone.isNotEmpty ? phone : 'User'),
        phoneNumber: phone,
        createdAt: DateTime.now(),
      );
    }
    if (_currentUser != null) {
      _mockUsersById[_currentUser!.id] = _currentUser!;
      if (_currentUser!.phoneNumber.isNotEmpty) {
        _mockUsersByPhone[_currentUser!.phoneNumber] = _currentUser!;
      }
    }
    _userStreamController.add(_currentUser);
  }

  // Find existing registered user by phone number
  Future<UserModel?> findUserByPhoneNumber(String rawPhoneNumber) async {
    final formatted = formatPhoneNumber(rawPhoneNumber);

    if (_mockUsersByPhone.containsKey(formatted)) {
      return _mockUsersByPhone[formatted];
    }

    if (_isFirebaseAvailable) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: formatted)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 3));

        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final user = UserModel.fromMap(doc.id, doc.data());
          _mockUsersById[user.id] = user;
          _mockUsersByPhone[formatted] = user;
          return user;
        }
      } catch (_) {}
    }

    return null;
  }

  // Get user profile by user ID
  Future<UserModel?> getUserById(String uid) async {
    if (_currentUser?.id == uid) {
      return _currentUser;
    }
    if (_mockUsersById.containsKey(uid)) {
      return _mockUsersById[uid];
    }
    if (_isFirebaseAvailable) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 2));
        if (doc.exists && doc.data() != null) {
          final user = UserModel.fromMap(uid, doc.data()!);
          _mockUsersById[uid] = user;
          if (user.phoneNumber.isNotEmpty) {
            _mockUsersByPhone[user.phoneNumber] = user;
          }
          return user;
        }
      } catch (_) {}
    }
    return null;
  }

  // Format phone number to E.164 (defaults to India +91 if 10 digits without prefix)
  String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!cleaned.startsWith('+')) {
      if (cleaned.length == 10) {
        cleaned = '+91$cleaned';
      } else {
        cleaned = '+$cleaned';
      }
    }
    return cleaned;
  }

  Future<void> sendOtp({
    required String rawPhoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    final formattedPhone = formatPhoneNumber(rawPhoneNumber);
    _pendingPhoneNumber = formattedPhone;

    if (_isFirebaseAvailable) {
      try {
        if (kIsWeb) {
          _webConfirmationResult = await FirebaseAuth.instance
              .signInWithPhoneNumber(formattedPhone);
          _verificationId = 'web_confirmation';
          onCodeSent('web_confirmation');
          return;
        }

        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (PhoneAuthCredential credential) async {
            final result = await FirebaseAuth.instance.signInWithCredential(credential);
            if (result.user != null) {
              await _syncUserProfile(result.user!);
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            onError(e.message ?? e.code);
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
        return;
      } catch (e) {
        // If web reCAPTCHA or platform isn't supported, or quota exceeded, fallback to test mode
        if (e.toString().contains('api-key-not-valid') ||
            e.toString().contains('no-app')) {
          _verificationId = 'mock_id';
          onCodeSent('mock_id');
          return;
        }
        onError(e.toString().replaceAll('Exception:', '').trim());
        return;
      }
    }

    // Local / Offline fallback
    _verificationId = 'mock_id';
    onCodeSent('mock_id');
  }

  Future<UserModel> verifyOtpAndSignIn({
    required String smsCode,
    String? name,
  }) async {
    final cleanCode = smsCode.trim();

    if (_isFirebaseAvailable && _verificationId != 'mock_id') {
      try {
        UserCredential userCredential;
        if (kIsWeb && _webConfirmationResult != null) {
          userCredential = await _webConfirmationResult!.confirm(cleanCode);
        } else if (_verificationId != null) {
          final credential = PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: cleanCode,
          );
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        } else {
          throw Exception('No verification session found. Please request OTP again.');
        }

        final user = userCredential.user!;
        await _syncUserProfile(user, name);
        return _currentUser!;
      } catch (e) {
        rethrow;
      }
    }

    // Fallback mock sign-in (allows testing with any 6-digit OTP e.g. 123456)
    final phone = _pendingPhoneNumber ?? '+919876543210';
    if (_mockUsersByPhone.containsKey(phone)) {
      final existing = _mockUsersByPhone[phone]!;
      if (name != null && name.trim().isNotEmpty && (existing.name == phone || existing.name.isEmpty)) {
        final updated = existing.copyWith(name: name.trim());
        _mockUsersByPhone[phone] = updated;
        _mockUsersById[updated.id] = updated;
        _currentUser = updated;
      } else {
        _currentUser = existing;
      }
    } else {
      final userModel = UserModel(
        id: 'usr_${phone.replaceAll(RegExp(r'\D'), '')}',
        name: name?.trim().isNotEmpty == true ? name!.trim() : phone,
        phoneNumber: phone,
        createdAt: DateTime.now(),
      );
      _mockUsersByPhone[phone] = userModel;
      _mockUsersById[userModel.id] = userModel;
      _currentUser = userModel;
    }
    _userStreamController.add(_currentUser);
    return _currentUser!;
  }

  // Sign in with Google
  Future<UserModel?> signInWithGoogle() async {
    if (_isFirebaseAvailable) {
      try {
        if (kIsWeb) {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          final userCredential =
              await FirebaseAuth.instance.signInWithPopup(googleProvider);
          if (userCredential.user != null) {
            await _syncUserProfile(userCredential.user!);
            return _currentUser;
          }
          return null;
        }

        // Native Mobile (Android / iOS)
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User canceled the sign-in prompt
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _syncUserProfile(userCredential.user!, googleUser.displayName);
          return _currentUser;
        }
        return null;
      } catch (e) {
        if (e.toString().contains('api-key-not-valid') ||
            e.toString().contains('no-app') ||
            e.toString().contains('network_error') ||
            e.toString().contains('channel-error')) {
          final userModel = UserModel(
            id: 'usr_google_demo',
            name: 'Google User',
            phoneNumber: '',
            createdAt: DateTime.now(),
          );
          _mockUsersById[userModel.id] = userModel;
          _currentUser = userModel;
          _userStreamController.add(_currentUser);
          return userModel;
        }
        rethrow;
      }
    }

    // Local / Testing / Demo fallback
    final userModel = UserModel(
      id: 'usr_google_demo',
      name: 'Google User',
      phoneNumber: '',
      createdAt: DateTime.now(),
    );
    _mockUsersById[userModel.id] = userModel;
    _currentUser = userModel;
    _userStreamController.add(_currentUser);
    return userModel;
  }

  // Update user's display name
  Future<void> updateUserName(String newName) async {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return;

    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(name: cleanName);
      _currentUser = updated;
      _mockUsersById[updated.id] = updated;
      if (updated.phoneNumber.isNotEmpty) {
        _mockUsersByPhone[updated.phoneNumber] = updated;
      }
      _prefs?.setString('user_name_${updated.id}', cleanName);
      _userStreamController.add(updated);

      if (_isFirebaseAvailable) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(updated.id)
              .update({'name': cleanName})
              .timeout(const Duration(seconds: 3));

          await FirebaseAuth.instance.currentUser?.updateDisplayName(cleanName);

          final groupsSnap = await FirebaseFirestore.instance
              .collection('groups')
              .where('members', arrayContains: updated.id)
              .get()
              .timeout(const Duration(seconds: 3));
          final batch = FirebaseFirestore.instance.batch();
          for (final doc in groupsSnap.docs) {
            batch.update(doc.reference, {'memberNames.${updated.id}': cleanName});
          }
          await batch.commit().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
  }

  // Update user's custom room/group order
  Future<void> updateGroupOrder(List<String> newOrder) async {
    if (_currentUser != null) {
      final updated = _currentUser!.copyWith(groupOrder: newOrder);
      _currentUser = updated;
      _mockUsersById[updated.id] = updated;
      if (updated.phoneNumber.isNotEmpty) {
        _mockUsersByPhone[updated.phoneNumber] = updated;
      }
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setStringList('user_group_order_${updated.id}', newOrder);
      _userStreamController.add(updated);

      if (_isFirebaseAvailable) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(updated.id)
              .set({'groupOrder': newOrder}, SetOptions(merge: true))
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
    }
  }

  Future<void> logOut() async {
    if (_isFirebaseAvailable) {
      try {
        await FirebaseAuth.instance.signOut();
        try {
          if (!kIsWeb) {
            await GoogleSignIn().signOut();
          }
        } catch (_) {}
      } catch (_) {}
    }
    _verificationId = null;
    _webConfirmationResult = null;
    _pendingPhoneNumber = null;
    _currentUser = null;
    _userStreamController.add(null);
  }
}
