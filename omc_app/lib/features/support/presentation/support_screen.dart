import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../content/data/app_content_repository.dart';
import '../data/support_config_data.dart';
import '../data/support_repository.dart';
import '../data/support_ticket.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedTopic = SupportConfigData.fallback.topics.first.title;
  bool _isSubmitting = false;

  bool get _canSubmit =>
      !_isSubmitting && _messageController.text.trim().length >= 10;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final supportConfigAsync = ref.watch(supportConfigProvider);
    final faqsAsync = ref.watch(appFaqsProvider);
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final supportConfig =
        supportConfigAsync.value ?? SupportConfigData.fallback;
    final supportTopics = supportConfig.topics.isNotEmpty
        ? supportConfig.topics
        : SupportConfigData.fallback.topics;

    if (!supportTopics.any((topic) => topic.title == _selectedTopic)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedTopic = supportTopics.first.title);
      });
    }

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const PremiumListHeader(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            subtitle:
                'Get help with services, documents, tax queries and request updates.',
            metaLabel: 'Help desk',
          ),
          const SizedBox(height: 20),
          _SupportHeroCard(channelCount: supportConfig.channels.length),
          const SizedBox(height: 16),
          _SupportCategoriesCard(topics: supportTopics),
          const SizedBox(height: 16),
          _CreateSupportTicketCard(
            selectedTopic: _selectedTopic,
            messageController: _messageController,
            isSubmitting: _isSubmitting,
            canSubmit: _canSubmit && capabilities.canCreateSupportTicket,
            canCreateTicket: capabilities.canCreateSupportTicket,
            lockedMessage: _lockedAccessMessage(capabilities),
            topics: supportTopics
                .map((topic) => topic.title)
                .toList(growable: false),
            onTopicChanged: _handleTopicChanged,
            onSubmit: _submitSupportTicket,
          ),
          const SizedBox(height: 16),
          _SupportTicketsCard(capabilities: capabilities),
          const SizedBox(height: 16),
          _BackendFaqCard(faqsAsync: faqsAsync),
          const SizedBox(height: 16),
          _SupportContactChannelsCard(config: supportConfig),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Business hours',
                  value: supportConfig.businessHours,
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Office',
                  value: supportConfig.officeAddress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTopicChanged(String? value) {
    if (value == null) return;
    final supportConfig =
        ref.read(supportConfigProvider).value ?? SupportConfigData.fallback;
    final topic = supportConfig.topics.firstWhere(
      (item) => item.title == value,
      orElse: () => SupportTopicConfig(
        title: value,
        subtitle: '',
        defaultMessage: '',
        iconKey: '',
        sortOrder: 0,
      ),
    );
    setState(() {
      _selectedTopic = value;
      if (_messageController.text.trim().isEmpty &&
          topic.defaultMessage.trim().isNotEmpty) {
        _messageController.text = topic.defaultMessage;
      }
    });
  }

  Future<void> _submitSupportTicket() async {
    final capabilities = ref.read(authControllerProvider).capabilities;
    if (!capabilities.canCreateSupportTicket) {
      _showSnack(_lockedAccessMessage(capabilities));
      return;
    }

    final repository = ref.read(supportRepositoryProvider);
    setState(() => _isSubmitting = true);

    try {
      await repository.createSupportTicket(
        topic: _selectedTopic,
        message: _messageController.text,
      );
      if (!mounted) return;
      setState(_messageController.clear);
      ref.invalidate(supportTicketsProvider);
      _showSnack('Support ticket submitted.');
    } on ApiError catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Support ticket could not be submitted right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  String _lockedAccessMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) {
      return 'Please sign in or create an account to open tracked support tickets.';
    }
    if (capabilities.isPending) {
      return 'Your account is under review. OMC team will verify your profile before enabling service access.';
    }
    if (capabilities.isRejected) {
      return 'This account is not approved for tracked support. Please use direct contact channels.';
    }
    return 'This account does not have access to tracked support tickets.';
  }
}

class _SupportHeroCard extends StatelessWidget {
  const _SupportHeroCard({required this.channelCount});

  final int channelCount;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBox(
                icon: Icons.support_agent_rounded,
                size: 56,
                iconSize: 30,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.14),
                  ),
                ),
                child: const Text(
                  'Active support',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('How can we help?', style: _TextStyles.heroTitle),
          const SizedBox(height: 8),
          const Text(
            'Create a tracked ticket or contact OMC directly for service, document, tax and payment support.',
            style: _TextStyles.body,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: _SupportMetric(
                  label: 'Tickets',
                  value: 'Tracked',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportMetric(
                  label: 'Channels',
                  value: '$channelCount options',
                  icon: Icons.forum_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportMetric extends StatelessWidget {
  const _SupportMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          _IconBox(icon: icon, size: 30, iconSize: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _TextStyles.metricValue,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _TextStyles.metricLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportCategoriesCard extends StatelessWidget {
  const _SupportCategoriesCard({required this.topics});

  final List<SupportTopicConfig> topics;

  @override
  Widget build(BuildContext context) {
    final sorted = [...topics]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Support topics',
            subtitle:
                'Choose the right area so OMC can route the request faster.',
          ),
          const SizedBox(height: 14),
          for (final topic in sorted.take(6)) ...[
            _TopicRow(topic: topic),
            if (topic != sorted.take(6).last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _CreateSupportTicketCard extends StatelessWidget {
  const _CreateSupportTicketCard({
    required this.selectedTopic,
    required this.messageController,
    required this.isSubmitting,
    required this.canSubmit,
    required this.canCreateTicket,
    required this.lockedMessage,
    required this.topics,
    required this.onTopicChanged,
    required this.onSubmit,
  });

  final String selectedTopic;
  final TextEditingController messageController;
  final bool isSubmitting;
  final bool canSubmit;
  final bool canCreateTicket;
  final String lockedMessage;
  final List<String> topics;
  final ValueChanged<String?> onTopicChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Create ticket',
            subtitle:
                'Approved customers can create tracked tickets from the app.',
          ),
          if (!canCreateTicket) ...[
            const SizedBox(height: 12),
            _LockedNote(message: lockedMessage),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: topics.contains(selectedTopic) ? selectedTopic : null,
            items: topics
                .map(
                  (topic) => DropdownMenuItem(value: topic, child: Text(topic)),
                )
                .toList(growable: false),
            onChanged: canCreateTicket ? onTopicChanged : null,
            decoration: const InputDecoration(
              labelText: 'Topic',
              prefixIcon: Icon(Icons.topic_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: messageController,
            enabled: canCreateTicket,
            minLines: 4,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Explain what you need help with...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSubmitting ? 'Submitting...' : 'Submit support ticket',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTicketsCard extends ConsumerWidget {
  const _SupportTicketsCard({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!capabilities.canViewSupportTickets &&
        !capabilities.canAccessInternalWorkspace) {
      return PremiumCard(
        padding: const EdgeInsets.all(18),
        child: _LockedNote(message: _lockedTicketsMessage(capabilities)),
      );
    }

    final ticketsAsync = ref.watch(supportTicketsProvider);
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  title: 'Your support tickets',
                  subtitle:
                      'Track submitted support requests and open ticket details.',
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(supportTicketsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ticketsAsync.when(
            data: (tickets) {
              if (tickets.isEmpty) return const _EmptyTickets();
              return Column(
                children: tickets
                    .take(4)
                    .map((ticket) {
                      return _TicketTile(ticket: ticket);
                    })
                    .toList(growable: false),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorNote(
              message: error is ApiError
                  ? error.message
                  : 'Support tickets could not be loaded right now.',
              onRetry: () => ref.invalidate(supportTicketsProvider),
            ),
          ),
        ],
      ),
    );
  }

  String _lockedTicketsMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) {
      return 'Sign in or create an account to view tracked support tickets.';
    }
    if (capabilities.isPending) {
      return 'Ticket history unlocks after OMC approves your profile.';
    }
    return 'This account does not have access to tracked support tickets.';
  }
}

class _BackendFaqCard extends StatelessWidget {
  const _BackendFaqCard({required this.faqsAsync});

  final AsyncValue<List<AppFaqItem>> faqsAsync;

  @override
  Widget build(BuildContext context) {
    return faqsAsync.maybeWhen(
      data: (faqs) {
        final visible = [...faqs]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (visible.isEmpty) return const SizedBox.shrink();
        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Frequently asked questions',
                subtitle:
                    'Backend-managed answers for common OMC support questions.',
              ),
              const SizedBox(height: 12),
              for (final faq in visible.take(5)) _FaqTile(faq: faq),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SupportContactChannelsCard extends StatelessWidget {
  const _SupportContactChannelsCard({required this.config});

  final SupportConfigData config;

  @override
  Widget build(BuildContext context) {
    final channels = [...config.channels]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Direct channels',
            subtitle: 'Use these for public or urgent support contact.',
          ),
          const SizedBox(height: 14),
          for (final channel in channels) ...[
            _ChannelTile(channel: channel),
            if (channel != channels.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final SupportTopicConfig topic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: _topicIcon(topic.iconKey), size: 40, iconSize: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(topic.title, style: _TextStyles.title),
              if (topic.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(topic.subtitle, style: _TextStyles.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const _IconBox(icon: Icons.confirmation_number_outlined),
      title: Text(ticket.subject.isEmpty ? ticket.id : ticket.subject),
      subtitle: Text(
        '${ticket.status.isEmpty ? 'Open' : ticket.status} • ${ticket.priority.isEmpty ? 'Medium' : ticket.priority}',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () =>
          context.push('/support-tickets/${Uri.encodeComponent(ticket.id)}'),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final AppFaqItem faq;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
      title: Text(faq.question, style: _TextStyles.title),
      subtitle: faq.category == null ? null : Text(faq.category!),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(faq.answer, style: _TextStyles.body),
        ),
      ],
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel});

  final SupportChannelConfig channel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: _channelIcon(channel), size: 42, iconSize: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(channel.label, style: _TextStyles.title),
              const SizedBox(height: 3),
              Text(channel.value, style: _TextStyles.body),
              if (channel.subtitle.trim().isNotEmpty)
                Text(channel.subtitle, style: _TextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBox(icon: icon, size: 38, iconSize: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _TextStyles.title),
              const SizedBox(height: 4),
              Text(value, style: _TextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _TextStyles.sectionTitle),
        const SizedBox(height: 6),
        Text(subtitle, style: _TextStyles.body),
      ],
    );
  }
}

class _LockedNote extends StatelessWidget {
  const _LockedNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InlineNote(icon: Icons.lock_outline_rounded, message: message);
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets();

  @override
  Widget build(BuildContext context) {
    return const _InlineNote(
      icon: Icons.inbox_outlined,
      message: 'No support tickets yet. Submitted tickets will appear here.',
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineNote(icon: Icons.cloud_off_outlined, message: message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon, size: 36, iconSize: 19),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: _TextStyles.body)),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 40, this.iconSize = 21});

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: iconSize),
    );
  }
}

class _TextStyles {
  static const heroTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  static const sectionTitle = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  static const title = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const metricValue = TextStyle(
    color: AppTheme.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const metricLabel = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}

IconData _topicIcon(String iconKey) {
  final key = iconKey.toLowerCase();
  if (key.contains('payment')) return Icons.account_balance_wallet_outlined;
  if (key.contains('technical')) return Icons.phonelink_setup_rounded;
  if (key.contains('sales')) return Icons.storefront_outlined;
  if (key.contains('pos')) return Icons.point_of_sale_rounded;
  if (key.contains('tax')) return Icons.receipt_long_outlined;
  return Icons.help_outline_rounded;
}

IconData _channelIcon(SupportChannelConfig channel) {
  if (channel.isWhatsApp) return Icons.chat_rounded;
  if (channel.isPhone) return Icons.phone_outlined;
  if (channel.isEmail) return Icons.email_outlined;
  return Icons.support_agent_rounded;
}
