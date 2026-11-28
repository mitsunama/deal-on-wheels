import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/wishlist_service.dart';
import 'common.dart';
import 'login_prompt.dart';

/// Heart toggle for saving a vehicle to the wishlist.
/// Visitors are asked to log in first; sellers can't save their own listing.
class WishlistButton extends StatelessWidget {
  final String vehicleId;
  final String sellerId;

  /// true = small dark circle for use on top of photos; false = plain icon button
  /// (app bars).
  final bool overlay;

  const WishlistButton({
    super.key,
    required this.vehicleId,
    required this.sellerId,
    this.overlay = false,
  });

  Future<void> _onPressed(BuildContext context) async {
    final service = WishlistService.instance;
    final wasLoggedIn = AuthService.instance.isLoggedIn;
    final wasSaved = service.contains(vehicleId);

    if (!wasLoggedIn) {
      final ok = await requireLogin(context, message: 'Login untuk menyimpan ke wishlist');
      if (!ok) return;
    }

    // Logging in rebuilds the tabs, so [context] may be gone by now: the action
    // itself only uses the global service, and snackbars check `mounted`.
    // A visitor who just logged in meant "save", never "remove".
    final save = wasLoggedIn ? !wasSaved : true;
    try {
      await service.setSaved(vehicleId, save);
      if (context.mounted) {
        showSnack(context, save ? 'Disimpan ke wishlist' : 'Dihapus dari wishlist');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.user?.id == sellerId) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: WishlistService.instance,
      builder: (context, _) {
        final saved = WishlistService.instance.contains(vehicleId);
        final tooltip = saved ? 'Hapus dari wishlist' : 'Simpan ke wishlist';
        final icon = Icon(saved ? Icons.favorite : Icons.favorite_border);

        if (overlay) {
          return IconButton(
            tooltip: tooltip,
            onPressed: () => _onPressed(context),
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            color: saved ? Colors.redAccent : Colors.white,
            iconSize: 20,
            icon: icon,
          );
        }
        return IconButton(
          tooltip: tooltip,
          onPressed: () => _onPressed(context),
          color: saved ? Colors.redAccent : null,
          icon: icon,
        );
      },
    );
  }
}
