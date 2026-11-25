/// Data models mirroring the Deal on Wheels API responses.
///
/// Note: Postgres BIGINT/NUMERIC columns are serialised by `pg` as strings,
/// so every numeric field is parsed through [asInt] which accepts both.

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v.toString();
  return int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// under_4 = fewer than 4 wheels (motorcycle, scooter...), four_plus = 4 wheels or more.
const Map<String, String> kVehicleTypes = {
  'under_4': 'Roda kurang dari 4 (sepeda motor, dsb.)',
  'four_plus': 'Roda 4 atau lebih (mobil, truk, dsb.)',
};

/// Short labels for the compact showroom dropdown and chips.
const Map<String, String> kVehicleTypesShort = {
  'under_4': 'Roda > 4',
  'four_plus': 'Roda 4 atau lebih',
};

const Map<String, String> kSortOptions = {
  'newest': 'Listing terbaru',
  'price_asc': 'Harga terendah sampai tertinggi',
  'price_desc': 'Harga tertinggi sampai terendah',
  'year_desc': 'Tahun kendaraan terbaru',
};

// ---------------------------------------------------------------- User

class User {
  final String id;
  final String username;
  final String email;
  final String? description;
  final String? profilePictureUrl;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.description,
    this.profilePictureUrl,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        username: j['username'] as String,
        email: (j['email'] ?? '') as String,
        description: j['description'] as String?,
        profilePictureUrl: j['profile_picture_url'] as String?,
        createdAt: asDate(j['created_at']),
      );
}

class AuthResult {
  final User user;
  final String token;
  const AuthResult(this.user, this.token);
}

// ------------------------------------------------------------- Vehicle

class VehicleImage {
  final String id;
  final String url;
  final int position;

  const VehicleImage({required this.id, required this.url, required this.position});

  factory VehicleImage.fromJson(Map<String, dynamic> j) => VehicleImage(
        id: j['id'] as String,
        url: (j['url'] ?? '') as String,
        position: asInt(j['position']) ?? 0,
      );
}

class Vehicle {
  final String id;
  final String sellerId;
  final String? sellerUsername;
  final String vehicleType; // under_4 | four_plus
  final String title;
  final String brand;
  final String model;
  final int year;
  final int? mileageKm;
  final String? transmission;
  final String? fuelType;
  final String? city;
  final int price;
  final String? description;
  final Map<String, dynamic> specs;
  final String status; // available | pending | sold
  final DateTime? createdAt;
  final String? coverImageUrl;
  final List<VehicleImage> images;

  const Vehicle({
    required this.id,
    required this.sellerId,
    this.sellerUsername,
    this.vehicleType = 'four_plus',
    required this.title,
    required this.brand,
    required this.model,
    required this.year,
    this.mileageKm,
    this.transmission,
    this.fuelType,
    this.city,
    required this.price,
    this.description,
    this.specs = const {},
    required this.status,
    this.createdAt,
    this.coverImageUrl,
    this.images = const [],
  });

  String? get thumbnail =>
      coverImageUrl ?? (images.isNotEmpty ? images.first.url : null);

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    final imgs = j['images'];
    return Vehicle(
      id: j['id'] as String,
      sellerId: j['seller_id'] as String,
      sellerUsername: j['seller_username'] as String?,
      vehicleType: (j['vehicle_type'] ?? 'four_plus') as String,
      title: j['title'] as String,
      brand: j['brand'] as String,
      model: j['model'] as String,
      year: asInt(j['year']) ?? 0,
      mileageKm: asInt(j['mileage_km']),
      transmission: j['transmission'] as String?,
      fuelType: j['fuel_type'] as String?,
      city: j['city'] as String?,
      price: asInt(j['price']) ?? 0,
      description: j['description'] as String?,
      specs: j['specs'] is Map
          ? Map<String, dynamic>.from(j['specs'] as Map)
          : <String, dynamic>{},
      status: (j['status'] ?? 'available') as String,
      createdAt: asDate(j['created_at']),
      coverImageUrl: j['cover_image_url'] as String?,
      images: imgs is List
          ? imgs
              .map((e) => VehicleImage.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const <VehicleImage>[],
    );
  }
}

/// Mutable filter state for `GET /vehicles`.
class VehicleFilters {
  String search;
  String vehicleType; // '' = all types
  String brand;
  String model;
  String city;
  int? year;
  int? minPrice;
  int? maxPrice;
  String status;
  String sort;

  VehicleFilters({
    this.search = '',
    this.vehicleType = '',
    this.brand = '',
    this.model = '',
    this.city = '',
    this.year,
    this.minPrice,
    this.maxPrice,
    this.status = 'available',
    this.sort = 'newest',
  });

  VehicleFilters clone() => VehicleFilters(
        search: search,
        vehicleType: vehicleType,
        brand: brand,
        model: model,
        city: city,
        year: year,
        minPrice: minPrice,
        maxPrice: maxPrice,
        status: status,
        sort: sort,
      );

  /// Number of filters set in the filter sheet (status/sort have their own UI).
  int get activeCount => [
        brand.isNotEmpty,
        model.isNotEmpty,
        city.isNotEmpty,
        year != null,
        minPrice != null,
        maxPrice != null,
      ].where((e) => e).length;

  Map<String, dynamic> toQuery() => {
        'q': search,
        'vehicleType': vehicleType,
        'brand': brand,
        'model': model,
        'city': city,
        'year': year,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'status': status,
        'sort': sort,
      };
}

// --------------------------------------------------------- Transaction

class DealTransaction {
  final String id;
  final String vehicleId;
  final String sellerId;
  final String buyerId;
  final int agreedPrice;
  final String status; // pending | completed | cancelled
  final DateTime? createdAt;
  final DateTime? completedAt;

  // Joined fields: the list endpoint only returns vehicleTitle, the detail
  // endpoint returns all of them, create/complete/cancel return none.
  final String? vehicleTitle;
  final String? buyerUsername;
  final String? sellerUsername;
  final String? brand;
  final String? model;
  final int? year;

  const DealTransaction({
    required this.id,
    required this.vehicleId,
    required this.sellerId,
    required this.buyerId,
    required this.agreedPrice,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.vehicleTitle,
    this.buyerUsername,
    this.sellerUsername,
    this.brand,
    this.model,
    this.year,
  });

  bool get isPending => status == 'pending';

  factory DealTransaction.fromJson(Map<String, dynamic> j) => DealTransaction(
        id: j['id'] as String,
        vehicleId: j['vehicle_id'] as String,
        sellerId: j['seller_id'] as String,
        buyerId: j['buyer_id'] as String,
        agreedPrice: asInt(j['agreed_price']) ?? 0,
        status: (j['status'] ?? 'pending') as String,
        createdAt: asDate(j['created_at']),
        completedAt: asDate(j['completed_at']),
        vehicleTitle: j['vehicle_title'] as String?,
        buyerUsername: j['buyer_username'] as String?,
        sellerUsername: j['seller_username'] as String?,
        brand: j['brand'] as String?,
        model: j['model'] as String?,
        year: asInt(j['year']),
      );
}

// -------------------------------------------------------------- Paging

class Paged<T> {
  final List<T> items;
  final int page;
  final int limit;
  final int total;

  const Paged({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
  });

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Paged(
        items: (j['items'] as List)
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList(),
        page: asInt(j['page']) ?? 1,
        limit: asInt(j['limit']) ?? 20,
        total: asInt(j['total']) ?? 0,
      );
}
