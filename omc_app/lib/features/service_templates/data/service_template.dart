class ServiceTemplate {
  const ServiceTemplate({
    required this.service,
    this.formSchema = const [],
    this.stages = const [],
    this.requiredDocuments = const [],
  });

  final String service;
  final List<ServiceTemplateField> formSchema;
  final List<ServiceStageTemplate> stages;
  final List<String> requiredDocuments;

  bool get hasDynamicFields => formSchema.isNotEmpty;

  factory ServiceTemplate.fromJson(Map<String, dynamic> json) {
    return ServiceTemplate(
      service: _readString(json, ['service', 'service_id', 'name']),
      formSchema: _readList(json, ['form_schema', 'formSchema', 'fields'])
          .map(ServiceTemplateField.fromJson)
          .where((field) => field.fieldname.isNotEmpty)
          .toList(growable: false),
      stages: _readList(json, ['stages', 'stage_templates', 'workflow'])
          .map(ServiceStageTemplate.fromJson)
          .where((stage) => stage.title.isNotEmpty || stage.stageKey.isNotEmpty)
          .toList(growable: false),
      requiredDocuments: _readStringList(json, [
        'required_documents',
        'requiredDocuments',
        'documents',
      ]),
    );
  }
}

class ServiceTemplateField {
  const ServiceTemplateField({
    required this.fieldname,
    required this.label,
    required this.fieldtype,
    this.options = const [],
    this.placeholder = '',
    this.description = '',
    this.isRequired = false,
    this.defaultValue = '',
    this.dependsOn = '',
    this.sortOrder = 0,
  });

  final String fieldname;
  final String label;
  final String fieldtype;
  final List<String> options;
  final String placeholder;
  final String description;
  final bool isRequired;
  final String defaultValue;
  final String dependsOn;
  final int sortOrder;

  factory ServiceTemplateField.fromJson(Map<String, dynamic> json) {
    return ServiceTemplateField(
      fieldname: _readString(json, ['fieldname', 'field_name', 'name']),
      label: _readString(json, ['label', 'title']),
      fieldtype: _readString(json, ['fieldtype', 'field_type', 'type'], 'Data'),
      options: _readStringList(json, ['options', 'values']),
      placeholder: _readString(json, ['placeholder', 'hint']),
      description: _readString(json, ['description', 'help', 'helper_text']),
      isRequired: _readBool(json, ['is_required', 'required', 'reqd']),
      defaultValue: _readString(json, ['default_value', 'default']),
      dependsOn: _readString(json, ['depends_on', 'dependsOn']),
      sortOrder: _readInt(json, ['sort_order', 'idx']),
    );
  }
}

class ServiceStageTemplate {
  const ServiceStageTemplate({
    required this.stageKey,
    required this.title,
    this.description = '',
    this.sortOrder = 0,
    this.isCustomerVisible = true,
  });

  final String stageKey;
  final String title;
  final String description;
  final int sortOrder;
  final bool isCustomerVisible;

  factory ServiceStageTemplate.fromJson(Map<String, dynamic> json) {
    return ServiceStageTemplate(
      stageKey: _readString(json, ['stage_key', 'stageKey', 'name']),
      title: _readString(json, ['title', 'stage_title', 'label']),
      description: _readString(json, ['description']),
      sortOrder: _readInt(json, ['sort_order', 'idx']),
      isCustomerVisible: _readBool(json, [
        'is_customer_visible',
        'isCustomerVisible',
        'visible',
      ], true),
    );
  }
}

List<Map<String, dynamic>> _readList(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    }
  }

  return const [];
}

List<String> _readStringList(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'\r?\n|,|;'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
  }

  return const [];
}

String _readString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = json[key];
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }

  return fallback;
}

bool _readBool(
  Map<String, dynamic> json,
  List<String> keys, [
  bool fallback = false,
]) {
  for (final key in keys) {
    final value = json[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (['1', 'true', 'yes', 'y'].contains(text)) return true;
      if (['0', 'false', 'no', 'n'].contains(text)) return false;
    }
  }

  return fallback;
}

int _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }

  return 0;
}
