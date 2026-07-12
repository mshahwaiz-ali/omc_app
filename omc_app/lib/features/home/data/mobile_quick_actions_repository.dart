import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';

final mobileQuickActionsRepositoryProvider =
    Provider<MobileQuickActionsRepository>(
      (ref) => MobileQuickActionsRepository(ref.watch(frappeClientProvider)),
    );

final mobileQuickActionsProvider = FutureProvider<List<MobileQuickAction>>((
  ref,
) {
  return ref.watch(mobileQuickActionsRepositoryProvider).fetchQuickActions();
});

class MobileQuickActionsRepository {
  const MobileQuickActionsRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<MobileQuickAction>> fetchQuickActions() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.mobileQuickActionsMethod,
      );
      final rows = _readRows(response, const [
        'quick_actions',
        'actions',
        'items',
      ]);
      final actions = rows
          .map(MobileQuickAction.fromJson)
          .where((action) => action.title.isNotEmpty)
          .toList(growable: false);

      return actions.isEmpty ? fallbackMobileQuickActions : actions;
    } catch (_) {
      return fallbackMobileQuickActions;
    }
  }

  List<Map<String, dynamic>> _readRows(
    Map<String, dynamic> response,
    List<String> keys,
  ) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false);
      }
    }

    if (message is List) {
      return message
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    }

    return const [];
  }
}

enum MobileQuickActionTargetType { route, feature, service, externalUrl }

enum MobileQuickActionStyle { normal, highlighted, urgent }

class MobileQuickAction {
  const MobileQuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.iconKey,
    required this.targetType,
    required this.targetValue,
    this.requiredCapability,
    this.badgeType = 'none',
    this.style = MobileQuickActionStyle.normal,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final MobileQuickActionTargetType targetType;
  final String targetValue;
  final String? requiredCapability;
  final String badgeType;
  final MobileQuickActionStyle style;
  final int sortOrder;

  String get iconAsset => iconAssetForKey(iconKey);

  factory MobileQuickAction.fromJson(Map<String, dynamic> json) {
    return MobileQuickAction(
      id: _readString(json, const ['id', 'name']),
      title: _readString(json, const ['title']),
      subtitle: _readString(json, const ['subtitle', 'description']),
      iconKey: _normalizeIconKey(_readString(json, const ['icon_key', 'icon'])),
      targetType: _targetType(_readString(json, const ['target_type'])),
      targetValue: _readString(json, const [
        'target_value',
        'route',
        'url',
        'service',
      ]),
      requiredCapability: _readNullableString(json, const [
        'required_capability',
      ]),
      badgeType: _normalizeKey(_readString(json, const ['badge_type'])),
      style: _style(_readString(json, const ['style'])),
      sortOrder: _readInt(json, const ['sort_order', 'idx']),
    );
  }
}

const fallbackMobileQuickActions = [
  MobileQuickAction(
    id: 'fallback-tax-return',
    title: 'Tax Return',
    subtitle: 'File now',
    iconKey: 'tax-return',
    targetType: MobileQuickActionTargetType.feature,
    targetValue: 'services',
    sortOrder: 10,
  ),
  MobileQuickAction(
    id: 'fallback-ntn',
    title: 'NTN',
    subtitle: 'Registration',
    iconKey: 'ntn',
    targetType: MobileQuickActionTargetType.feature,
    targetValue: 'services',
    sortOrder: 20,
  ),
  MobileQuickAction(
    id: 'fallback-gst',
    title: 'GST',
    subtitle: 'Registration',
    iconKey: 'gst',
    targetType: MobileQuickActionTargetType.feature,
    targetValue: 'services',
    sortOrder: 30,
  ),
  MobileQuickAction(
    id: 'fallback-documents',
    title: 'Documents',
    subtitle: 'Upload',
    iconKey: 'documents',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/documents',
    requiredCapability: 'can_view_documents',
    badgeType: 'documents',
    sortOrder: 40,
  ),
  MobileQuickAction(
    id: 'fallback-track',
    title: 'Track',
    subtitle: 'Request',
    iconKey: 'track',
    targetType: MobileQuickActionTargetType.route,
    targetValue: '/my-services',
    requiredCapability: 'can_track_requests',
    sortOrder: 50,
  ),
  MobileQuickAction(
    id: 'fallback-calculator',
    title: 'Calculator',
    subtitle: 'Tax',
    iconKey: 'calculator',
    targetType: MobileQuickActionTargetType.feature,
    targetValue: 'calculator',
    requiredCapability: 'can_use_tax_calculator',
    sortOrder: 60,
  ),
];

String iconAssetForKey(String key) {
  return switch (_normalizeIconKey(key)) {
    'tax-return' => 'assets/icons/mobile_actions/tax_return.svg',
    'ntn' => 'assets/icons/mobile_actions/ntn.svg',
    'gst' => 'assets/icons/mobile_actions/gst.svg',
    'documents' => 'assets/icons/mobile_actions/documents.svg',
    'track' => 'assets/icons/mobile_actions/track.svg',
    'calculator' => 'assets/icons/mobile_actions/calculator.svg',
    'support' => 'assets/icons/mobile_actions/support.svg',
    'payments' => 'assets/icons/mobile_actions/payments.svg',
    'message' => 'assets/icons/mobile_actions/message.svg',
    'knowledge' => 'assets/icons/mobile_actions/knowledge.svg',
    'services' => 'assets/icons/mobile_actions/services.svg',
    'notifications' => 'assets/icons/mobile_actions/notifications.svg',
    'dashboard' => 'assets/icons/mobile_actions/dashboard.svg',
    _ => 'assets/icons/mobile_actions/services.svg',
  };
}

MobileQuickActionTargetType _targetType(String value) {
  return switch (_normalizeKey(value)) {
    'feature' => MobileQuickActionTargetType.feature,
    'service' => MobileQuickActionTargetType.service,
    'external-url' ||
    'external_url' ||
    'url' => MobileQuickActionTargetType.externalUrl,
    _ => MobileQuickActionTargetType.route,
  };
}

MobileQuickActionStyle _style(String value) {
  return switch (_normalizeKey(value)) {
    'highlighted' => MobileQuickActionStyle.highlighted,
    'urgent' => MobileQuickActionStyle.urgent,
    _ => MobileQuickActionStyle.normal,
  };
}

String _normalizeIconKey(String value) =>
    _normalizeKey(value).isEmpty ? 'services' : _normalizeKey(value);

String _normalizeKey(String value) {
  return value.trim().toLowerCase().replaceAll('_', '-').replaceAll(' ', '-');
}

String _readString(Map<String, dynamic> data, List<String> keys) {
  return _readNullableString(data, keys) ?? '';
}

String? _readNullableString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final text = data[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _readInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}
