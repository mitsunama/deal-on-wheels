// Replaces the default counter test, which no longer applies.
// If your package is not importable through these relative paths, switch them
// to package:<your_package_name>/... imports.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../lib/models/models.dart';
import '../lib/services/api_service.dart';

void main() {
  test('transaction parses BIGINT price sent as a string', () {
    final t = DealTransaction.fromJson({
      'id': 'a1b2c3d4-0000-0000-0000-000000000000',
      'vehicle_id': 'v',
      'seller_id': 's',
      'buyer_id': 'b',
      'agreed_price': '250000000', // pg returns BIGINT as string
      'status': 'pending',
      'created_at': '2026-11-21T09:00:00.000Z',
      'completed_at': null,
      'vehicle_title': 'Toyota Avanza 2018',
    });
    expect(t.agreedPrice, 250000000);
    expect(t.isPending, true);
    expect(t.vehicleTitle, 'Toyota Avanza 2018');
    expect(t.completedAt, isNull);
  });

  test('vehicle list item parses cover image and numeric strings', () {
    final v = Vehicle.fromJson({
      'id': 'v',
      'seller_id': 's',
      'title': 'Honda Jazz',
      'brand': 'Honda',
      'model': 'Jazz',
      'year': 2019,
      'mileage_km': '42000',
      'city': 'Semarang',
      'price': '215000000',
      'status': 'available',
      'cover_image_url': 'https://cdn.example/x.jpg',
    });
    expect(v.price, 215000000);
    expect(v.mileageKm, 42000);
    expect(v.thumbnail, 'https://cdn.example/x.jpg');
    expect(v.images, isEmpty);
  });

  test('image type sniffing accepts only jpeg/png/webp', () {
    expect(sniffImageMime(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])), 'jpeg');
    expect(
      sniffImageMime(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0])),
      'png',
    );
    expect(sniffImageMime(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0, 0, 0, 0, 0])), isNull);
  });
}
