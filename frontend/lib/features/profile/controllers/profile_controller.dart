// lib/features/profile/profile_controller.dart

import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';


class ProfileController extends ChangeNotifier {
  ProfileModel? _profile;
  bool _isLoading = false;

  ProfileModel? get profile  => _profile;
  bool get isLoading         => _isLoading;
  bool get hasPhone          => _profile?.hasPhone ?? false;

  Future<void> loadProfile({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _profile = await ProfileService.getMyProfile();
    } on ProfileServiceException {
      _profile = null;
    } catch (_) {
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _profile  = null;
    _isLoading = false;
    notifyListeners();
  }
}