class WorkAddress {
  const WorkAddress({
    this.formattedAddress,
    this.details,
    this.latitude,
    this.longitude,
    this.googlePlaceId,
    this.city,
    this.district,
    this.province,
    this.postalCode,
    this.country,
    this.source,
    this.updatedOn,
    this.geolocation,
    this.googleMapsUrl,
    this.hasWorkAddress = false,
    this.needsPrompt = false,
  });

  const WorkAddress.empty() : this();

  final String? formattedAddress;
  final String? details;
  final double? latitude;
  final double? longitude;
  final String? googlePlaceId;
  final String? city;
  final String? district;
  final String? province;
  final String? postalCode;
  final String? country;
  final String? source;
  final DateTime? updatedOn;
  final String? geolocation;
  final String? googleMapsUrl;
  final bool hasWorkAddress;
  final bool needsPrompt;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory WorkAddress.fromProfileJson(Map<String, dynamic> json) {
    final formattedAddress = _nullableString(json['work_address']);
    final latitude = _nullableDouble(json['work_latitude']);
    final longitude = _nullableDouble(json['work_longitude']);

    final backendHasAddress = _boolValue(json['has_work_address']);
    final derivedHasAddress =
        formattedAddress != null && latitude != null && longitude != null;

    return WorkAddress(
      formattedAddress: formattedAddress,
      details: _nullableString(json['work_address_details']),
      latitude: latitude,
      longitude: longitude,
      googlePlaceId: _nullableString(json['google_place_id']),
      city: _nullableString(json['work_city']),
      district: _nullableString(json['work_district']),
      province: _nullableString(json['work_province']),
      postalCode: _nullableString(json['work_postal_code']),
      country: _nullableString(json['work_country']),
      source: _nullableString(json['work_location_source']),
      updatedOn: _nullableDateTime(json['work_location_updated_on']),
      geolocation: _nullableString(json['work_geolocation']),
      googleMapsUrl: _nullableString(json['work_google_maps_url']),
      hasWorkAddress: backendHasAddress || derivedHasAddress,
      needsPrompt: _boolValue(json['needs_work_address_prompt']),
    );
  }

  Map<String, dynamic> toPayload() {
    return {
      'work_address': formattedAddress ?? '',
      'work_address_details': details ?? '',
      'work_latitude': latitude,
      'work_longitude': longitude,
      'google_place_id': googlePlaceId ?? '',
      'work_city': city ?? '',
      'work_district': district ?? '',
      'work_province': province ?? '',
      'work_postal_code': postalCode ?? '',
      'work_country': country ?? '',
      'work_location_source': source ?? '',
    };
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static DateTime? _nullableDateTime(dynamic value) {
    final text = _nullableString(value);
    return text == null ? null : DateTime.tryParse(text);
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
