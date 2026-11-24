import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'common.dart';

typedef VehicleSubmit = Future<void> Function(
  Map<String, dynamic> payload,
  List<PickedImage> newImages,
);

class _SpecRow {
  final TextEditingController key;
  final TextEditingController value;
  final dynamic original; // keeps non-string JSON values intact if untouched

  _SpecRow({String k = '', String v = '', this.original})
      : key = TextEditingController(text: k),
        value = TextEditingController(text: v);

  dynamic valueOut() {
    final o = original;
    if (o != null && o is! String && value.text == o.toString()) return o;
    return value.text;
  }

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// Form shared by CreateVehicleScreen and UpdateVehicleScreen.
/// Validation mirrors the API's zod schema (create/update vehicle).
class VehicleForm extends StatefulWidget {
  final Vehicle? initial;
  final String submitLabel;
  final int maxNewImages;
  final VehicleSubmit onSubmit;

  const VehicleForm({
    super.key,
    this.initial,
    required this.submitLabel,
    this.maxNewImages = 10,
    required this.onSubmit,
  });

  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  static const _transmissions = ['Manual', 'Automatic', 'CVT', 'Semi-automatic'];
  static const _fuels = ['Petrol', 'Diesel', 'Hybrid', 'Electric', 'LPG'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  late final TextEditingController _city;
  late final TextEditingController _price;
  late final TextEditingController _description;
  String _vehicleType = 'four_plus';
  String? _transmission;
  String? _fuel;
  final List<_SpecRow> _specs = [];
  final List<PickedImage> _images = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _title = TextEditingController(text: v?.title ?? '');
    _brand = TextEditingController(text: v?.brand ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v == null ? '' : '${v.year}');
    _mileage = TextEditingController(text: v?.mileageKm?.toString() ?? '');
    _city = TextEditingController(text: v?.city ?? '');
    _price = TextEditingController(text: v == null ? '' : '${v.price}');
    _description = TextEditingController(text: v?.description ?? '');
    _vehicleType = v?.vehicleType ?? 'four_plus';
    _transmission = v?.transmission;
    _fuel = v?.fuelType;
    v?.specs.forEach((k, val) {
      _specs.add(_SpecRow(k: k, v: val.toString(), original: val));
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _brand, _model, _year, _mileage, _city, _price, _description]) {
      c.dispose();
    }
    for (final r in _specs) {
      r.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String label, {int max = 1000, int min = 1}) {
    final t = (v ?? '').trim();
    if (t.length < min) return min == 1 ? '$label is required' : '$label: at least $min characters';
    if (t.length > max) return '$label: at most $max characters';
    return null;
  }

  List<DropdownMenuItem<String?>> _options(List<String> base, String? current) {
    final list = [...base];
    if (current != null && current.isNotEmpty && !list.contains(current)) list.add(current);
    return [
      const DropdownMenuItem<String?>(value: null, child: Text('Not specified')),
      for (final o in list) DropdownMenuItem<String?>(value: o, child: Text(o)),
    ];
  }

  Future<void> _addPhotos() async {
    final remaining = widget.maxNewImages - _images.length;
    final picked = await pickImages(context, maxCount: remaining);
    if (picked.isNotEmpty && mounted) setState(() => _images.addAll(picked));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? nullIfEmpty(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final specs = <String, dynamic>{};
    for (final r in _specs) {
      final k = r.key.text.trim();
      if (k.isEmpty) continue;
      specs[k] = r.valueOut();
    }

    final payload = <String, dynamic>{
      'vehicleType': _vehicleType,
      'title': _title.text.trim(),
      'brand': _brand.text.trim(),
      'model': _model.text.trim(),
      'year': int.parse(_year.text.trim()),
      'price': int.parse(_price.text.trim()),
      'mileageKm': _mileage.text.trim().isEmpty ? null : int.parse(_mileage.text.trim()),
      'transmission': _transmission,
      'fuelType': _fuel,
      'city': nullIfEmpty(_city),
      'description': nullIfEmpty(_description),
      'specs': specs,
    };

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(payload, List.of(_images));
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _vehicleType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vehicle type *'),
            items: [
              for (final e in kVehicleTypes.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _vehicleType = v ?? 'four_plus'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *'),
            validator: (v) => _required(v, 'Title', min: 3, max: 150),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Brand *'),
                  validator: (v) => _required(v, 'Brand', max: 60),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Model *'),
                  validator: (v) => _required(v, 'Model', max: 60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Year *'),
                  validator: (v) {
                    final y = int.tryParse((v ?? '').trim());
                    if (y == null) return 'Year is required';
                    if (y < 1900 || y > 2100) return '1900-2100';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _mileage,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Mileage (km)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            decoration: const InputDecoration(labelText: 'Price *', prefixText: 'Rp '),
            validator: (v) {
              final p = int.tryParse((v ?? '').trim());
              if (p == null || p <= 0) return 'Enter a price greater than 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _transmission,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Transmission'),
                  items: _options(_transmissions, _transmission),
                  onChanged: (v) => setState(() => _transmission = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _fuel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Fuel type'),
                  items: _options(_fuels, _fuel),
                  onChanged: (v) => setState(() => _fuel = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (v) => (v ?? '').trim().length > 80 ? 'At most 80 characters' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            validator: (v) => (v ?? '').length > 5000 ? 'At most 5000 characters' : null,
          ),

          // ---- specs -------------------------------------------------
          const SizedBox(height: 24),
          Text('Specifications',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Optional extras such as Color, Engine, Seats.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          for (var i = 0; i < _specs.length; i++)
            Padding(
              key: ObjectKey(_specs[i]),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _specs[i].key,
                      decoration: const InputDecoration(labelText: 'Name', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _specs[i].value,
                      decoration: const InputDecoration(labelText: 'Value', isDense: true),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      final row = _specs[i];
                      setState(() => _specs.removeAt(i));
                      // Dispose after the field is out of the tree.
                      WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
                    },
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _specs.add(_SpecRow())),
              icon: const Icon(Icons.add),
              label: const Text('Add specification'),
            ),
          ),

          // ---- photos ------------------------------------------------
          const SizedBox(height: 16),
          Text('Photos',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('JPEG, PNG or WebP, up to 5 MB each.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          if (_images.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _images[i].bytes,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _addPhotos,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text('Add photos (${_images.length}/${widget.maxNewImages})'),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.submitLabel),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
