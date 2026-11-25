import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widget/common.dart';
import '../widget/image_viewer.dart';
import '../widget/login_prompt.dart';
import 'update_vehicle.dart';

class VehicleDetailScreen extends StatefulWidget {
  final String vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _pageCtrl = PageController();
  Vehicle? _vehicle;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _imgIndex = 0;

  bool get _isOwner => AuthService.instance.isLoggedIn &&
      _vehicle?.sellerId == AuthService.instance.user?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final v = await api.getVehicle(widget.vehicleId);
      if (!mounted) return;
      setState(() {
        _vehicle = v;
        _loading = false;
        _imgIndex = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  /// Buyer starts a deal: POST /vehicles/:id/transactions.
  /// On success the vehicle turns `pending` and the user lands on the
  /// Transactions tab where the new deal is listed.
  Future<void> _startDeal() async {
    final v = _vehicle!;
    if (!await requireLogin(context, message: 'Login untuk membeli kendaraan')) return;
    if (!mounted) return;
    setState(() {}); // the visitor is now logged in: refresh owner-dependent UI
    if (_isOwner) {
      showSnack(context, 'Ini listing Anda.', error: true);
      return;
    }
    final offer = await showDialog<int>(
      context: context,
      builder: (_) => _OfferDialog(listedPrice: v.price),
    );
    if (offer == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.createTransaction(v.id, agreedPrice: offer == v.price ? null : offer);
      AppEvents.dataChanged();
      AppEvents.selectedTab.value = 1;
      messenger.showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Transaksi dimulai. Menunggu konfirmasi penjual.'),
      ));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, errorText(e), error: true);
      _load(silent: true); // status may have changed (409)
    }
  }

  Future<void> _edit() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => UpdateVehicleScreen(vehicle: _vehicle!)),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus listing?',
      message: 'Kendaraan akan dihapus dari showroom.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.deleteVehicle(widget.vehicleId);
      AppEvents.dataChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showSnack(context, errorText(e), error: true);
    }
  }

  // ------------------------------------------------------------------ UI

  void _goToImage(int i, int count) {
    if (i < 0 || i >= count) return;
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openFullView(Vehicle v) async {
    final urls = v.images.map((i) => i.url).toList();
    if (urls.isEmpty) return;
    final last = await FullImageViewer.open(context, urls, _imgIndex);
    if (last != null && mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(last);
  }

  Widget _arrow(IconData icon, String tooltip, VoidCallback? onPressed,
      {required Alignment align}) {
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          color: Colors.white,
          disabledColor: Colors.white24,
          icon: Icon(icon),
        ),
      ),
    );
  }

  Widget _gallery(Vehicle v) {
    final images = v.images;
    final count = images.length;
    return SizedBox(
      height: 260,
      child: Stack(
        children: [
          if (images.isEmpty)
            const NetImage(url: null, iconSize: 72)
          else
            // Mouse drag is off by default for PageView on desktop/web.
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: count,
                onPageChanged: (i) => setState(() => _imgIndex = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openFullView(v),
                  child: NetImage(url: images[i].url),
                ),
              ),
            ),
          if (count > 0)
            Positioned(
              left: 12,
              top: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openFullView(v),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fullscreen, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Tampilan penuh',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (count > 1) ...[
            _arrow(
              Icons.chevron_left,
              'Foto sebelumnya',
              _imgIndex > 0 ? () => _goToImage(_imgIndex - 1, count) : null,
              align: Alignment.centerLeft,
            ),
            _arrow(
              Icons.chevron_right,
              'Foto selanjutnya',
              _imgIndex < count - 1 ? () => _goToImage(_imgIndex + 1, count) : null,
              align: Alignment.centerRight,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    GestureDetector(
                      onTap: () => _goToImage(i, count),
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _imgIndex ? Colors.white : Colors.white54,
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_imgIndex + 1}/$count',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fact(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _content(Vehicle v) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _gallery(v),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      formatPrice(v.price),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  StatusChip(status: v.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(v.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Di-list oleh @${v.sellerUsername ?? 'unknown'}'
                '${_isOwner ? ' (anda)' : ''} \u2022 ${formatDate(v.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _fact(Icons.two_wheeler, 'Tipe', kVehicleTypes[v.vehicleType] ?? v.vehicleType),
                  _fact(Icons.business, 'Merek', v.brand),
                  _fact(Icons.directions_car, 'Model', v.model),
                  _fact(Icons.calendar_today, 'Tahun', '${v.year}'),
                  _fact(Icons.speed, 'Kilometer', v.mileageKm == null ? null : formatKm(v.mileageKm)),
                  _fact(Icons.settings, 'Transmisi', v.transmission),
                  _fact(Icons.local_gas_station, 'Bahan bakar', v.fuelType),
                  _fact(Icons.place_outlined, 'Lokasi', v.city),
                ],
              ),
              if ((v.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Deskripsi',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(v.description!),
              ],
              if (v.specs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Spesifikasi',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final e in v.specs.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(e.key, style: const TextStyle(color: Colors.grey)),
                        ),
                        Expanded(child: Text('${e.value}')),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  ButtonStyle _boxedStyle(Color color) => OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: color, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget? _bottomBar(Vehicle v) {
    final theme = Theme.of(context);
    Widget child;
    if (_isOwner) {
      final hint = v.status == 'pending'
          ? 'Sebuah pembeli telah memulai transaksi. Konfirmasi atau batalkan di menu Transaksi.'
          : 'Kendaraan telah dijual.';
      if (v.status == 'available') {
        child = Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit listing'),
                style: _boxedStyle(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus listing'),
                style: _boxedStyle(theme.colorScheme.error),
              ),
            ),
          ],
        );
      } else {
        child = Text(
          hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        );
      }
    } else if (v.status == 'available') {
      child = FilledButton.icon(
        onPressed: _busy ? null : _startDeal,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.handshake_outlined),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Beli seharga ${formatPrice(v.price)}'),
        ),
      );
    } else {
      child = Text(
        v.status == 'pending'
            ? 'Kendaraan sedang dalam proses transaksi dan tidak tersedia untuk saat ini.'
            : 'Kendaraan telah dijual.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _vehicle;
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.title ?? 'Kendaraan', overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null || v == null)
              ? ErrorView(message: _error ?? 'Kendaraan tidak ditemukan', onRetry: _load)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: RefreshIndicator(
                      onRefresh: () => _load(silent: true),
                      child: _content(v),
                    ),
                  ),
                ),
      bottomNavigationBar: (v == null) ? null : _bottomBar(v),
    );
  }
}

/// Lets the buyer confirm the deal and optionally propose another price.
/// Returns the agreed price in whole currency units.
class _OfferDialog extends StatefulWidget {
  final int listedPrice;
  const _OfferDialog({required this.listedPrice});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  late final TextEditingController _price =
      TextEditingController(text: '${widget.listedPrice}');
  String? _error;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _confirm() {
    final p = int.tryParse(_price.text.trim());
    if (p == null || p <= 0) {
      setState(() => _error = 'Masukkan harga lebih dari 0');
      return;
    }
    Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mulai transaksi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga awal: ${formatPrice(widget.listedPrice)}'),
            const SizedBox(height: 4),
            const Text(
              'Kendaraan telah berada dalam proses transaksi. Pembeli harus mengonfirmasi '
              'penjualan, Anda maupun penjual dapat membatalkan proses transaksi.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: 'Harga nego',
                prefixText: 'Rp ',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _confirm, child: const Text('Mulai transaksi')),
      ],
    );
  }
}
