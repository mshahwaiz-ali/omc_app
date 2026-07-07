import 'dart:convert';

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.feeLabel,
    required this.completionTime,
    required this.requirements,
    this.governmentFeeLabel,
    this.description,
    this.shortDescription,
    this.processSteps = const [],
    this.requiredDocuments = const [],
    this.supportMessage,
    this.wizardType,
    this.wizardConfig = const {},
  });

  final String id;
  final String title;
  final String category;
  final String feeLabel;
  final String? governmentFeeLabel;
  final String completionTime;
  final List<String> requirements;
  final String? description;
  final String? shortDescription;
  final List<String> processSteps;
  final List<String> requiredDocuments;
  final String? supportMessage;
  final String? wizardType;
  final Map<String, dynamic> wizardConfig;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: _readString(json, ['id', 'name', 'service_id']),
      title: _readString(json, [
        'title',
        'service_title',
        'service_name',
        'serviceName',
        'label',
      ]),
      category: _readString(json, [
        'category',
        'service_category',
        'service_group',
        'group',
      ]),
      feeLabel: _readString(json, [
        'feeLabel',
        'fee_label',
        'fee',
        'price_label',
        'amount_label',
        'service_fee',
      ]),
      governmentFeeLabel: _readNullableString(json, [
        'governmentFeeLabel',
        'government_fee_label',
        'government_fee',
      ]),
      completionTime: _readString(json, [
        'completionTime',
        'completion_time',
        'timeline',
        'duration',
        'estimated_time',
        'turnaround_time',
      ]),
      description: _readNullableString(json, [
        'description',
        'details',
        'long_description',
      ]),
      shortDescription: _readNullableString(json, [
        'shortDescription',
        'short_description',
        'summary',
        'intro',
      ]),
      supportMessage: _readNullableString(json, [
        'supportMessage',
        'support_message',
        'whatsapp_message',
      ]),
      wizardType: _readNullableString(json, [
        'wizardType',
        'wizard_type',
        'request_wizard_type',
      ]),
      wizardConfig: _readMap(json, [
        'wizardConfig',
        'wizard_config',
        'request_wizard_config',
      ]),
      requirements: _readStringList(json, [
        'requirements',
        'required_information',
        'required_info',
      ]),
      processSteps: _readStringList(json, [
        'processSteps',
        'process_steps',
        'steps',
      ]),
      requiredDocuments: _readStringList(json, [
        'requiredDocuments',
        'required_documents',
        'documents',
        'required_docs',
        'attachments_required',
      ]),
    );
  }

  static List<String> _readStringList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }

    return const [];
  }

  static Map<String, dynamic> _readMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value is Map<String, dynamic>) {
        return value;
      }

      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }

      if (value is String && value.trim().isNotEmpty) {
        final decoded = _tryDecodeJsonMap(value);
        if (decoded != null) return decoded;
      }
    }

    return const {};
  }

  static Map<String, dynamic>? _tryDecodeJsonMap(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    return _readNullableString(json, keys) ?? '';
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }
}
