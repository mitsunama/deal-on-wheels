import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widget/common.dart';
import 'vehicle_detail.dart';

/// Lists the signed-in user's deals (as buyer and as seller).
///
/// Lifecycle (enforced by the API):
///   buyer starts deal  -> transaction `pending`,  vehicle `pending`
///   seller completes   -> transaction `completed`, vehicle `sold`
///   buyer/seller cancel-> transaction `cancelled`, vehicle `available`
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  static const _statuses = {
    '': 'Semua',
    'pending': 'Dalam transaksi',
    'completed': 'Selesai',
    'cancelled': 'Batal',
  };

  final _scroll = ScrollController();

  String _role = ''; // '' | buyer | seller
  String _status = ''; // '' | pending | completed | cancelled
  List<DealTransaction> _items = [];
  int _page = 1;
  int _total = 0;
  int _gen = 0; // discards responses from superseded requests
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    AppEvents.dataVersion.addListener(_onDataChanged);
    _refresh();
  }

  @override
  void dispose() {
    AppEvents.dataVersion.removeListener(_onDataChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onDataChanged() => _refresh(silent: true);

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _loadMore();
  }

  Future<void> _refresh({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await api.listTransactions(
        role: _role.isEmpty ? null : _role,
        status: _status.isEmpty ? null : _status,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _page = 1;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      if (silent && _items.isNotEmpty) {
        showSnack(context, errorText(e), error: true);
      } else {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _items.length >= _total) return;
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final res = await api.listTransactions(
        role: _role.isEmpty ? null : _role,
        status: _status.isEmpty ? null : _status,
        page: _page + 1,
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = [..._items, ...res.items];
        _page += 1;
        _total = res.total;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      showSnack(context, errorText(e), error: true);
    }
  }

  void _openDetail(DealTransaction t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => TransactionDetailSheet(transactionId: t.id),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: '', label: Text('Semua')),
              ButtonSegment(value: 'buyer', label: Text('Beli')),
              ButtonSegment(value: 'seller', label: Text('Jual')),
            ],
            selected: {_role},
            onSelectionChanged: (s) {
              setState(() => _role = s.first);
              _refresh();
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in _statuses.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        setState(() => _status = e.key);
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _refresh(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            ErrorView(message: _error!, onRetry: _refresh),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(silent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Tidak ada transaksi.')),
            SizedBox(height: 4),
            Center(
              child: Text(
                'Pilih sebuah kendaraan di Showroom dan tekan tombol "Beli" untuk bertransaksi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(silent: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final t = _items[i];
          return _TransactionTile(transaction: t, onTap: () => _openDetail(t));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        foregroundColor: Colors.white,
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: _body(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final DealTransaction transaction;
  final VoidCallback onTap;

  const _TransactionTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.user?.id;
    final selling = transaction.sellerId == me;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: onTap,
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: Icon(selling ? Icons.sell_outlined : Icons.shopping_bag_outlined),
        ),
        title: Text(
          transaction.vehicleTitle ?? 'Kendaraan',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${selling ? 'Jual' : 'Beli'} \u2022 ${formatPrice(transaction.agreedPrice)}\n'
          '${formatDate(transaction.createdAt)}',
        ),
        trailing: StatusChip(status: transaction.status),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Bottom sheet showing one transaction with the actions the current user may
/// take: the seller can complete a pending deal, either party can cancel it.
class TransactionDetailSheet extends StatefulWidget {
  final String transactionId;
  const TransactionDetailSheet({super.key, required this.transactionId});

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  DealTransaction? _tx;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _actionError;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final t = await api.getTransaction(widget.transactionId);
      if (!mounted) return;
      setState(() {
        _tx = t;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _act(bool complete) async {
    final t = _tx!;
    final ok = await confirmDialog(
      context,
      title: complete ? 'Konfirmasi penjualan?' : 'Batalkan transaksi?',
      message: complete
          ? 'Kendaraan telah dijual kepada ${t.buyerUsername ?? 'the buyer'} '
              'dengan harga ${formatPrice(t.agreedPrice)}. Penjualan tidak dapat dibatalkan.'
          : 'Transaksi telah dibatalkan dan kendaraan telah kembali tersedia. '
              'Tindakan tidak dapat dibatalkan.',
      confirmLabel: complete ? 'Konfirmasi penjualan' : 'Batalkan transaksi',
      destructive: !complete,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _notice = null;
    });
    try {
      if (complete) {
        await api.completeTransaction(t.id);
      } else {
        await api.cancelTransaction(t.id);
      }
      AppEvents.dataChanged(); // refresh the list and the showroom
      await _load(silent: true);
      if (mounted) {
        setState(() => _notice = complete
            ? 'Penjualan dikonfirmasi. Kendaraan telah dijual.'
            : 'Transaksi dibatalkan. Kendaraan kembali tersedia.');
      }
    } catch (e) {
      if (mounted) setState(() => _actionError = errorText(e));
      // State may have changed on the server (e.g. other party cancelled).
      AppEvents.dataChanged();
      await _load(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, {required bool error}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _content(DealTransaction t) {
    final me = AuthService.instance.user?.id;
    final isSeller = t.sellerId == me;
    final theme = Theme.of(context);
    final carName = [
      if (t.brand != null) t.brand,
      if (t.model != null) t.model,
      if (t.year != null) '(${t.year})',
    ].join(' ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Transaksi',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            StatusChip(status: t.status),
          ],
        ),
        const SizedBox(height: 12),
        Text(t.vehicleTitle ?? 'Kendaraan',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (carName.isNotEmpty) Text(carName, style: const TextStyle(color: Colors.grey)),
        const Divider(height: 28),
        _row('Harga akhir', formatPrice(t.agreedPrice), bold: true),
        _row('Peran Anda', isSeller ? 'Penjual' : 'Pembeli'),
        _row('Pembeli',
            '@${t.buyerUsername ?? '-'}${t.buyerId == me ? '  (anda)' : ''}'),
        _row('Penjual',
            '@${t.sellerUsername ?? '-'}${t.sellerId == me ? '  (anda)' : ''}'),
        _row('Dimulai', formatDate(t.createdAt)),
        if (t.completedAt != null) _row('Selesai', formatDate(t.completedAt)),
        _row('Referensi', t.id.length >= 8 ? t.id.substring(0, 8) : t.id),
        if (_notice != null) _banner(_notice!, error: false),
        if (_actionError != null) _banner(_actionError!, error: true),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VehicleDetailScreen(vehicleId: t.vehicleId),
                    ),
                  ),
          icon: const Icon(Icons.directions_car_outlined),
          label: const Text('Lihat kendaraan'),
        ),
        if (t.isPending) ...[
          const SizedBox(height: 8),
          if (isSeller)
            FilledButton.icon(
              onPressed: _busy ? null : () => _act(true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Konfirmasi penjualan'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Menunggu persetujuan penjual.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: _busy ? null : () => _act(false),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Batalkan transaksi'),
          ),
        ],
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    } else if (_error != null || _tx == null) {
      child = SizedBox(
        height: 240,
        child: ErrorView(message: _error ?? 'Tidak ditemukan', onRetry: _load),
      );
    } else {
      child = _content(_tx!);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: child,
      ),
    );
  }
}
