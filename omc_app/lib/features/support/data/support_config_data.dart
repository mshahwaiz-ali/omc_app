import '../../../core/config/support_config.dart' as local_config;

class SupportConfigData {
  const SupportConfigData({
    required this.channels,
    required this.topics,
    required this.businessHours,
    required this.officeAddress,
    required this.whatsappMessage,
    required this.isFallback,
  });

  final List<SupportChannelConfig> channels;
  final List<SupportTopicConfig> topics;
  final String businessHours;
  final String officeAddress;
  final String whatsappMessage;
  final bool isFallback;

  static SupportConfigData get fallback {
    return const SupportConfigData(
      channels: [
        SupportChannelConfig(
          channelType: 'whatsapp',
          label: 'WhatsApp support',
          value: local_config.SupportConfig.whatsappNumber,
          subtitle: 'Fastest option for service and document queries',
          sortOrder: 1,
        ),
        SupportChannelConfig(
          channelType: 'phone',
          label: 'Call OMC',
          value: local_config.SupportConfig.phoneNumber,
          subtitle: 'Talk to OMC support during business hours',
          sortOrder: 2,
        ),
        SupportChannelConfig(
          channelType: 'email',
          label: 'Email support',
          value: local_config.SupportConfig.email,
          subtitle: 'Send service, tax, document and payment queries',
          sortOrder: 3,
        ),
      ],
      topics: [
        SupportTopicConfig(
          title: 'Income Tax',
          subtitle: 'Returns, NTN, IRIS and filing help',
          defaultMessage:
              'Hello OMC, I need help with an income tax or IRIS matter.',
          iconKey: 'tax',
          sortOrder: 1,
        ),
        SupportTopicConfig(
          title: 'POS & Digital Invoicing',
          subtitle: 'POS setup, FBR integration and invoices',
          defaultMessage:
              'Hello OMC, I need help with POS or digital invoicing.',
          iconKey: 'pos',
          sortOrder: 2,
        ),
        SupportTopicConfig(
          title: 'Sales Tax',
          subtitle: 'GST registration and sales tax queries',
          defaultMessage:
              'Hello OMC, I need help with sales tax or GST registration.',
          iconKey: 'sales_tax',
          sortOrder: 3,
        ),
        SupportTopicConfig(
          title: 'Technical Support',
          subtitle: 'App, login, upload or tracking issues',
          defaultMessage:
              'Hello OMC, I need technical support for the mobile app.',
          iconKey: 'technical',
          sortOrder: 4,
        ),
        SupportTopicConfig(
          title: 'Payment Support',
          subtitle: 'Invoices, receipts and payment follow-up',
          defaultMessage:
              'Hello OMC, I need help with payment or invoice status.',
          iconKey: 'payment',
          sortOrder: 5,
        ),
      ],
      businessHours: local_config.SupportConfig.businessHours,
      officeAddress: local_config.SupportConfig.officeAddress,
      whatsappMessage: local_config.SupportConfig.whatsappMessage,
      isFallback: true,
    );
  }

  factory SupportConfigData.fromApiResponse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return fallback;

    final message = data['message'];
    final raw = message is Map<String, dynamic> ? message : data;

    final channels = _readList(raw['channels'] ?? raw['support_channels'])
        .map(SupportChannelConfig.fromJson)
        .where((channel) => channel.isUsable)
        .toList(growable: false);

    final topics = _readList(raw['topics'] ?? raw['support_topics'])
        .map(SupportTopicConfig.fromJson)
        .where((topic) => topic.title.trim().isNotEmpty)
        .toList(growable: false);

    final fallbackConfig = fallback;

    return SupportConfigData(
      channels: channels.isEmpty ? fallbackConfig.channels : channels,
      topics: topics.isEmpty ? fallbackConfig.topics : topics,
      businessHours: _stringValue(raw['business_hours']).isNotEmpty
          ? _stringValue(raw['business_hours'])
          : fallbackConfig.businessHours,
      officeAddress: _stringValue(raw['office_address']).isNotEmpty
          ? _stringValue(raw['office_address'])
          : fallbackConfig.officeAddress,
      whatsappMessage: _stringValue(raw['whatsapp_message']).isNotEmpty
          ? _stringValue(raw['whatsapp_message'])
          : fallbackConfig.whatsappMessage,
      isFallback:
          raw['fallback'] == true ||
          raw['is_fallback'] == true ||
          channels.isEmpty ||
          topics.isEmpty,
    );
  }

  SupportChannelConfig? get whatsappChannel => _firstChannelByType('whatsapp');

  SupportChannelConfig? get phoneChannel => _firstChannelByType('phone');

  SupportChannelConfig? get emailChannel => _firstChannelByType('email');

  SupportChannelConfig? _firstChannelByType(String type) {
    final cleanType = type.toLowerCase();
    for (final channel in channels) {
      if (channel.channelType.toLowerCase().contains(cleanType)) {
        return channel;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _readList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';
}

class SupportChannelConfig {
  const SupportChannelConfig({
    required this.channelType,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.sortOrder,
  });

  final String channelType;
  final String label;
  final String value;
  final String subtitle;
  final int sortOrder;

  factory SupportChannelConfig.fromJson(Map<String, dynamic> json) {
    return SupportChannelConfig(
      channelType: _stringValue(json['channel_type'] ?? json['type']),
      label: _stringValue(json['label'] ?? json['title']),
      value: _stringValue(json['value']),
      subtitle: _stringValue(json['subtitle'] ?? json['description']),
      sortOrder: _intValue(json['sort_order']),
    );
  }

  bool get isUsable => label.trim().isNotEmpty && value.trim().isNotEmpty;

  bool get isWhatsApp => channelType.toLowerCase().contains('whatsapp');

  bool get isPhone =>
      channelType.toLowerCase().contains('phone') ||
      channelType.toLowerCase().contains('call');

  bool get isEmail => channelType.toLowerCase().contains('email');

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SupportTopicConfig {
  const SupportTopicConfig({
    required this.title,
    required this.subtitle,
    required this.defaultMessage,
    required this.iconKey,
    required this.sortOrder,
  });

  final String title;
  final String subtitle;
  final String defaultMessage;
  final String iconKey;
  final int sortOrder;

  factory SupportTopicConfig.fromJson(Map<String, dynamic> json) {
    return SupportTopicConfig(
      title: _stringValue(json['title'] ?? json['label']),
      subtitle: _stringValue(json['subtitle'] ?? json['description']),
      defaultMessage: _stringValue(
        json['default_message'] ?? json['message'] ?? json['whatsapp_message'],
      ),
      iconKey: _stringValue(json['icon_key'] ?? json['icon']),
      sortOrder: _intValue(json['sort_order']),
    );
  }

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
