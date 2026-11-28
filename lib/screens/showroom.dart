import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widget/common.dart';
import '../widget/login_prompt.dart';
import '../widget/wishlist_button.dart';
import 'create_vehicle.dart';
import 'vehicle_detail.dart';

class ShowroomScreen extends StatefulWidget {
  const ShowroomScreen({super.key});

  @override
  State<ShowroomScreen> createState() => _ShowroomScreenState();
}

class _ShowroomScreenState extends State<ShowroomScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  VehicleFilters _filters = VehicleFilters();
  List<Vehicle> _items = [];
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
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onDataChanged() => _refresh(silent: true);

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 400) _loadMore();
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
      final res = await api.listVehicles(_filters);
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
      final res = await api.listVehicles(_filters, page: _page + 1);
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

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<VehicleFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() => _filters = result);
      _refresh();
    }
  }

  Future<void> _sell() async {
    if (!await requireLogin(context, message: 'Login untuk menambahkan kendaraan')) return;
    // Logging in rebuilds the tabs (this State is disposed), so push through the
    // root navigator instead of this widget's context.
    await rootNavigatorKey.currentState?.push<bool>(
      MaterialPageRoute(builder: (_) => const CreateVehicleScreen()),
    );
  }

  void _onSearchChanged(String text) {
    setState(() {}); // toggles the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _applySearch);
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim();
    if (q == _filters.search) return;
    _filters.search = q;
    _refresh();
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _applySearch();
              },
              decoration: InputDecoration(
                hintText: 'Cari merek, model, lokasi...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Bersihkan',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          _debounce?.cancel();
                          _applySearch();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              _debounce?.cancel();
              FocusScope.of(context).unfocus();
              _applySearch();
            },
            icon: const Icon(Icons.search),
            label: const Text('Cari'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _controlsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filters.vehicleType,
              isExpanded: true,
              decoration: _dropdownDecoration('Jenis kendaraan'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua')),
                for (final e in kVehicleTypesShort.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                setState(() => _filters.vehicleType = v ?? '');
                _refresh();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filters.sort,
              isExpanded: true,
              decoration: _dropdownDecoration('Sortir berdasarkan'),
              items: [
                for (final e in kSortOptions.entries)
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) {
                if (v == null || v == _filters.sort) return;
                setState(() => _filters.sort = v);
                _refresh();
              },
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: _filters.activeCount > 0,
              label: Text('${_filters.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
            label: const Text('Filter'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// One removable chip per active filter, so the current filter is always visible.
  Widget _activeFilterChips() {
    final f = _filters;
    final chips = <Widget>[];

    void chip(String label, VoidCallback clear) {
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InputChip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(clear);
            _refresh();
          },
        ),
      ));
    }

    if (f.brand.isNotEmpty) chip('Merek: ${f.brand}', () => f.brand = '');
    if (f.model.isNotEmpty) chip('Model: ${f.model}', () => f.model = '');
    if (f.city.isNotEmpty) chip('Lokasi: ${f.city}', () => f.city = '');
    if (f.year != null) chip('Tahun: ${f.year}', () => f.year = null);
    if (f.minPrice != null || f.maxPrice != null) {
      final lo = f.minPrice == null ? null : formatPrice(f.minPrice!);
      final hi = f.maxPrice == null ? null : formatPrice(f.maxPrice!);
      final label = lo != null && hi != null
          ? '$lo - $hi'
          : lo != null
              ? 'Dari $lo'
              : 'Sampai $hi';
      chip('Harga: $label', () {
        f.minPrice = null;
        f.maxPrice = null;
      });
    }

    final hasAny = chips.isNotEmpty || f.vehicleType.isNotEmpty;
    final summary = StringBuffer('${_total} kendaraan');
    if (f.vehicleType.isNotEmpty) summary.write(' \u2022 ${kVehicleTypesShort[f.vehicleType]}');
    if (f.search.isNotEmpty) summary.write(' \u2022 "${f.search}"');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (chips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _loading ? 'Loading...' : '$summary',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    )
                  else
                    ...chips,
                ],
              ),
            ),
          ),
          if (hasAny)
            TextButton(
              onPressed: () {
                setState(() {
                  _filters = VehicleFilters(search: f.search, sort: f.sort);
                });
                _refresh();
              },
              child: const Text('Bersihkan filter'),
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
            Icon(Icons.search_off, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Tidak ada kendaraan yang dapat ditemukan')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(silent: true),
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisExtent: 290,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final v = _items[i];
          return VehicleCard(
            vehicle: v,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: v.id)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF303030),
        foregroundColor: Colors.white,
        title: const Text('Showroom'),
        actions: [
          if (!AuthService.instance.isLoggedIn)
            TextButton.icon(
              onPressed: () => requireLogin(context),
              icon: const Icon(Icons.login),
              label: const Text('Log in'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sell,
        icon: const Icon(Icons.add),
        label: const Text('Jual'),
      ),
      body: Column(
        children: [
          _searchBar(),
          _controlsRow(),
          _activeFilterChips(),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}

/// Grid card for a vehicle (shared by the showroom and the wishlist).
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = vehicle;
    final sub = [
      if (v.city != null && v.city!.isNotEmpty) v.city!,
      if (v.mileageKm != null) formatKm(v.mileageKm),
    ].join(' \u2022 ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(url: v.thumbnail),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            v.vehicleType == 'under_4' ? Icons.two_wheeler : Icons.directions_car,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            kVehicleTypesShort[v.vehicleType] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (v.status != 'available')
                    Positioned(top: 8, right: 8, child: StatusChip(status: v.status)),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: WishlistButton(
                      vehicleId: v.id,
                      sellerId: v.sellerId,
                      overlay: true,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(v.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${v.brand} ${v.model} \u2022 ${v.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final VehicleFilters initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _city;
  late final TextEditingController _year;
  late final TextEditingController _minPrice;
  late final TextEditingController _maxPrice;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _brand = TextEditingController(text: f.brand);
    _model = TextEditingController(text: f.model);
    _city = TextEditingController(text: f.city);
    _year = TextEditingController(text: f.year?.toString() ?? '');
    _minPrice = TextEditingController(text: f.minPrice?.toString() ?? '');
    _maxPrice = TextEditingController(text: f.maxPrice?.toString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_brand, _model, _city, _year, _minPrice, _maxPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return (v == null || v <= 0) ? null : v;
  }

  void _apply() {
    final f = widget.initial.clone()
      ..brand = _brand.text.trim()
      ..model = _model.text.trim()
      ..city = _city.text.trim()
      ..year = _int(_year)
      ..minPrice = _int(_minPrice)
      ..maxPrice = _int(_maxPrice);
    Navigator.pop(context, f);
  }

  void _reset() {
    final f = widget.initial.clone()
      ..brand = ''
      ..model = ''
      ..city = ''
      ..year = null
      ..minPrice = null
      ..maxPrice = null;
    Navigator.pop(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _brand,
                    decoration: const InputDecoration(labelText: 'Merek'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _model,
                    decoration: const InputDecoration(labelText: 'Model'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Lokasi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Tahun'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Harga terendah'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: const InputDecoration(labelText: 'Harga tertinggi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _apply, child: const Text('Filter')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
