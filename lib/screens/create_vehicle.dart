import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widget/common.dart';
import '../widget/vehicle_form.dart';
import 'vehicle_detail.dart';

class CreateVehicleScreen extends StatelessWidget {
  const CreateVehicleScreen({super.key});

  Future<void> _create(
    BuildContext context,
    Map<String, dynamic> payload,
    List<PickedImage> images,
  ) async {
    final vehicle = await api.createVehicle(payload);

    // Photos are a second request. If it fails the listing still exists, so
    // tell the user instead of failing the whole form (which would duplicate it).
    String? photoProblem;
    if (images.isNotEmpty) {
      try {
        await api.addVehicleImages(vehicle.id, images);
      } catch (e) {
        photoProblem = errorText(e);
      }
    }
    AppEvents.dataChanged();
    if (!context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicleId: vehicle.id)),
    );
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(photoProblem == null
          ? 'Kendaraan berhasil di-list'
          : 'Kendaraan berhasil di-list, namun gagal mengunggah foto: $photoProblem. '
              'Anda dapat menambahkannya menggunakan tombol Edit.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jual kendaraan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: VehicleForm(
                submitLabel: 'Tambahkan kendaraan ke list',
                onSubmit: (payload, images) => _create(context, payload, images),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
