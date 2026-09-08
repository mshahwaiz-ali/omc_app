/// Validate authoritative input before the tolerant display model parses it.
/// An explicitly empty schema is valid. Malformed rows must not disappear.
void validateServiceTemplate(Map<String, dynamic> data) {
  final fields = data['form_schema'];
  final stages = data['stages'];
  if (fields is! List || stages is! List) {
    throw const FormatException('The service form is unavailable.');
  }
  final names = <String>{};
  for (final row in fields) {
    if (row is! Map<String, dynamic>) {
      throw const FormatException('Invalid service form field.');
    }
    final name = row['fieldname'];
    final label = row['label'];
    final type = row['fieldtype'];
    if (name is! String ||
        name.trim().isEmpty ||
        name.trim() != name ||
        label is! String ||
        label.trim().isEmpty ||
        type is! String ||
        type.trim().isEmpty ||
        !names.add(name)) {
      throw const FormatException('Invalid or duplicated service form field.');
    }
    if (row.containsKey('options') && row['options'] is! List) {
      throw const FormatException('Invalid service field options.');
    }
    if (row['options'] is List &&
        (row['options'] as List).any((v) => v is! String)) {
      throw const FormatException('Invalid service field option.');
    }
    final requiredValue = row['is_required'];
    if (requiredValue != null &&
        requiredValue != true &&
        requiredValue != false &&
        requiredValue != 0 &&
        requiredValue != 1 &&
        requiredValue != '0' &&
        requiredValue != '1') {
      throw const FormatException('Invalid required-field flag.');
    }
  }
  for (final stage in stages) {
    if (stage is! Map<String, dynamic> ||
        stage['stage_key'] is! String ||
        (stage['stage_key'] as String).trim().isEmpty) {
      throw const FormatException('Invalid service stage.');
    }
  }
}
