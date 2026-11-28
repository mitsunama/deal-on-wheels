import 'package:flutter/foundation.dart';

import 'api_service.dart';

/// The logged-in user's saved vehicle ids. Hearts on cards and the detail page
/// listen to this, so toggling anywhere updates every screen immediately.
class WishlistService extends ChangeNotifier {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final Set<String> _ids = {};

  Set<String> get ids => Set.unmodifiable(_ids);
  bool contains(String vehicleId) => _ids.contains(vehicleId);

  /// Fetches the saved ids from the server (call after login / session restore).
  Future<void> load() async {
    try {
      final ids = await api.getWishlistIds();
      _ids
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal memuat wishlist: $e');
    }
  }

  /// Forget everything (call on logout).
  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }

  /// Saves or removes a vehicle. The UI updates immediately; if the server
  /// call fails the change is rolled back and the error is rethrown.
  Future<void> setSaved(String vehicleId, bool saved) async {
    final had = _ids.contains(vehicleId);
    if (had == saved) return;
    saved ? _ids.add(vehicleId) : _ids.remove(vehicleId);
    notifyListeners();
    try {
      if (saved) {
        await api.addToWishlist(vehicleId);
      } else {
        await api.removeFromWishlist(vehicleId);
      }
    } catch (_) {
      had ? _ids.add(vehicleId) : _ids.remove(vehicleId);
      notifyListeners();
      rethrow;
    }
  }
}
