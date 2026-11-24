import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widget/common.dart';
import '../widget/vehicle_form.dart';

class UpdateVehiclePage extends StatefulWidget {
  final Vehicle vehicle;
  const UpdateVehiclePage({super.key, required this.vehicle});

  @override
  State<UpdateVehiclePage> createState() => _UpdateVehiclePageState();
}

class _UpdateVehiclePageState extends State<UpdateVehiclePage> {
  late final List<VehicleImage> _images = List.of(widget.vehicle.images);
  String? _removingId;

  Future<void> _removeImage(VehicleImage img) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove photo?',
      message: 'This photo will be deleted from the listing.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _removingId = img.id);
    try {
      await api.deleteVehicleImage(widget.vehicle.id, img.id);
      AppEvents.dataChanged();
      if (mounted) setState(() => _images.removeWhere((i) => i.id == img.id));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _removingId = null);
    }
  }

  Future<void> _save(Map<String, dynamic> payload, List<PickedImage> newImages) async {
    await api.updateVehicle(widget.vehicle.id, payload);

    String? photoProblem;
    if (newImages.isNotEmpty) {
      try {
        await api.addVehicleImages(widget.vehicle.id, newImages);
      } catch (e) {
        photoProblem = errorText(e);
      }
    }
    AppEvents.dataChanged();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(photoProblem == null
          ? 'Changes saved'
          : 'Changes saved, but photos failed to upload: $photoProblem'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit vehicle')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Current photos',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_images.isEmpty)
                    Text('No photos yet.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
                  else
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final img = _images[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: NetImage(url: img.url),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: _removingId == img.id
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : InkWell(
                                        onTap: () => _removeImage(img),
                                        child: const CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.black54,
                                          child: Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  const Divider(height: 32),
                  VehicleForm(
                    initial: widget.vehicle,
                    submitLabel: 'Save changes',
                    maxNewImages: 10 - _images.length,
                    onSubmit: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
