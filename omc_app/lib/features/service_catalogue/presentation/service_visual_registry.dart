import 'package:flutter/material.dart';

import '../data/service_item.dart';

@immutable
class ServiceVisual {
  const ServiceVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

const Map<String, IconData> _serviceIcons = {
  'business_setup': Icons.domain_add_outlined,
  'company_registration': Icons.apartment_outlined,
  'tax_filing': Icons.receipt_long_outlined,
  'tax_registration': Icons.how_to_reg_outlined,
  'gst': Icons.request_quote_outlined,
  'accounting': Icons.calculate_outlined,
  'audit': Icons.fact_check_outlined,
  'documents': Icons.description_outlined,
  'certificate': Icons.workspace_premium_outlined,
  'legal': Icons.gavel_outlined,
  'visa': Icons.flight_takeoff_rounded,
  'payroll': Icons.groups_outlined,
  'payments': Icons.payments_outlined,
  'compliance': Icons.verified_user_outlined,
  'consultation': Icons.support_agent_outlined,
  'licensing': Icons.badge_outlined,
  'trademark': Icons.verified_outlined,
  'bookkeeping': Icons.menu_book_outlined,
  'banking': Icons.account_balance_outlined,
  'general_service': Icons.grid_view_rounded,
};

const Map<String, Color> _serviceAccents = {
  'navy': Color(0xFF243447),
  'blue': Color(0xFF2563A6),
  'teal': Color(0xFF0F766E),
  'green': Color(0xFF2F7D4A),
  'amber': Color(0xFFB7791F),
  'orange': Color(0xFFC05A2B),
  'violet': Color(0xFF7457A6),
  'indigo': Color(0xFF4856A6),
  'slate': Color(0xFF526173),
  'burgundy': Color(0xFF7A3045),
};

IconData serviceIconFor(String? key) {
  return _serviceIcons[_normalizeKey(key)] ?? _serviceIcons['general_service']!;
}

Color serviceAccentFor(String? family) {
  return _serviceAccents[_normalizeKey(family)] ?? _serviceAccents['slate']!;
}

ServiceVisual serviceVisualFor(ServiceItem service) {
  final normalizedIcon = _normalizeKey(service.iconKey);
  final normalizedFamily = _normalizeKey(service.colorFamily);

  final hasBackendIcon = _serviceIcons.containsKey(normalizedIcon);
  final hasBackendColor = _serviceAccents.containsKey(normalizedFamily);

  if (hasBackendIcon || hasBackendColor) {
    return ServiceVisual(
      icon: hasBackendIcon
          ? _serviceIcons[normalizedIcon]!
          : _legacyVisualFor(service).icon,
      color: hasBackendColor
          ? _serviceAccents[normalizedFamily]!
          : _legacyVisualFor(service).color,
    );
  }

  return _legacyVisualFor(service);
}

ServiceVisual _legacyVisualFor(ServiceItem service) {
  final source =
      '${service.category} ${service.title} ${service.wizardType ?? ''}'
          .toLowerCase();

  if (source.contains('visa') || source.contains('immigration')) {
    return const ServiceVisual(
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF0F766E),
    );
  }

  if (source.contains('gst') || source.contains('sales tax')) {
    return const ServiceVisual(
      icon: Icons.request_quote_outlined,
      color: Color(0xFF4856A6),
    );
  }

  if (source.contains('tax') || source.contains('ntn')) {
    return const ServiceVisual(
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF7457A6),
    );
  }

  if (source.contains('business') ||
      source.contains('company') ||
      source.contains('setup')) {
    return const ServiceVisual(
      icon: Icons.domain_add_outlined,
      color: Color(0xFF243447),
    );
  }

  if (source.contains('document') || source.contains('certificate')) {
    return const ServiceVisual(
      icon: Icons.description_outlined,
      color: Color(0xFF0F766E),
    );
  }

  if (source.contains('payment') ||
      source.contains('receipt') ||
      source.contains('invoice')) {
    return const ServiceVisual(
      icon: Icons.payments_outlined,
      color: Color(0xFFC05A2B),
    );
  }

  if (source.contains('account') || source.contains('bookkeep')) {
    return const ServiceVisual(
      icon: Icons.calculate_outlined,
      color: Color(0xFF2563A6),
    );
  }

  if (source.contains('audit') || source.contains('compliance')) {
    return const ServiceVisual(
      icon: Icons.fact_check_outlined,
      color: Color(0xFF2F7D4A),
    );
  }

  if (source.contains('legal') ||
      source.contains('license') ||
      source.contains('trademark')) {
    return const ServiceVisual(
      icon: Icons.gavel_outlined,
      color: Color(0xFF7A3045),
    );
  }

  if (source.contains('payroll') ||
      source.contains('hr') ||
      source.contains('employee')) {
    return const ServiceVisual(
      icon: Icons.groups_outlined,
      color: Color(0xFF0F766E),
    );
  }

  if (source.contains('support') ||
      source.contains('consult') ||
      source.contains('case') ||
      source.contains('request')) {
    return const ServiceVisual(
      icon: Icons.support_agent_outlined,
      color: Color(0xFF526173),
    );
  }

  return const ServiceVisual(
    icon: Icons.grid_view_rounded,
    color: Color(0xFF526173),
  );
}

String _normalizeKey(String? value) {
  return (value ?? '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
