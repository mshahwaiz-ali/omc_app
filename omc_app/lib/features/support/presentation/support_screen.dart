import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_premium.dart';
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

  void _handleMessageChanged() => setState(() {});

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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
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
          _SupportCategoriesCard(config: supportConfig, topics: supportTopics),
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
                color: OmcPremium.track,
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
                  color: OmcPremium.documents,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SupportMetric(
                  label: 'Channels',
                  value: '$channelCount options',
                  icon: Icons.forum_outlined,
                  color: OmcPremium.track,
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
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          _IconBox(icon: icon, size: 30, iconSize: 17, color: color),
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
  const _SupportCategoriesCard({required this.config, required this.topics});

  final SupportConfigData config;
  final List<SupportTopicConfig> topics;

  @override
  Widget build(BuildContext context) {
    final sorted = [...topics]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final whatsappChannel = config.whatsappChannel;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Support topics',
            subtitle: 'Tap a topic to open WhatsApp with a ready message.',
          ),
          const SizedBox(height: 14),
          for (final topic in sorted.take(6)) ...[
            _TopicRow(
              topic: topic,
              whatsappChannel: whatsappChannel,
              fallbackMessage: config.whatsappMessage,
            ),
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

class _SupportTicketsCard extends ConsumerStatefulWidget {
  const _SupportTicketsCard({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  ConsumerState<_SupportTicketsCard> createState() =>
      _SupportTicketsCardState();
}

class _SupportTicketsCardState extends ConsumerState<_SupportTicketsCard> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final capabilities = widget.capabilities;
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
                      'Track active support and review closed ticket history.',
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
              final activeTickets = tickets
                  .where((ticket) => !ticket.isClosed)
                  .toList(growable: false);
              final closedTickets = tickets
                  .where((ticket) => ticket.isClosed)
                  .toList(growable: false);
              final selectedTickets = _selectedTab == 0
                  ? activeTickets
                  : closedTickets;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SupportTicketTabs(
                    selectedIndex: _selectedTab,
                    activeCount: activeTickets.length,
                    closedCount: closedTickets.length,
                    onChanged: (index) => setState(() => _selectedTab = index),
                  ),
                  const SizedBox(height: 14),
                  if (selectedTickets.isEmpty)
                    _EmptyTickets(
                      message: _selectedTab == 0
                          ? 'No active support tickets right now.'
                          : 'No closed support tickets yet.',
                    )
                  else
                    Column(
                      children: selectedTickets
                          .take(6)
                          .map((ticket) {
                            return _TicketTile(ticket: ticket);
                          })
                          .toList(growable: false),
                    ),
                ],
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

class _SupportTicketTabs extends StatelessWidget {
  const _SupportTicketTabs({
    required this.selectedIndex,
    required this.activeCount,
    required this.closedCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int activeCount;
  final int closedCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      selected: {selectedIndex},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      segments: [
        ButtonSegment<int>(
          value: 0,
          icon: const Icon(Icons.support_agent_rounded, size: 18),
          label: Text('Active ($activeCount)'),
        ),
        ButtonSegment<int>(
          value: 1,
          icon: const Icon(Icons.history_rounded, size: 18),
          label: Text('Closed ($closedCount)'),
        ),
      ],
    );
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
            subtitle: 'Tap an option to contact OMC directly.',
          ),
          const SizedBox(height: 14),
          for (final channel in channels) ...[
            _ChannelTile(
              channel: channel,
              whatsappMessage: config.whatsappMessage,
            ),
            if (channel != channels.last) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.whatsappChannel,
    required this.fallbackMessage,
  });

  final SupportTopicConfig topic;
  final SupportChannelConfig? whatsappChannel;
  final String fallbackMessage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final channel = whatsappChannel;
          if (channel == null) {
            _showChannelError(context);
            return;
          }
          _openSupportChannel(
            context,
            channel,
            _topicMessage(topic, fallbackMessage),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _IconBox(
                icon: _topicIcon(topic.iconKey),
                size: 40,
                iconSize: 20,
                color: _topicColor(topic.iconKey),
              ),
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
              Icon(
                Icons.support_agent_rounded,
                color: _topicColor(topic.iconKey),
                size: 20,
              ),
            ],
          ),
        ),
      ),
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
      leading: _IconBox(
        icon: ticket.isClosed
            ? Icons.check_circle_outline_rounded
            : Icons.confirmation_number_outlined,
        color: ticket.isClosed ? OmcPremium.success : _priorityColor(ticket),
      ),
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
  const _ChannelTile({required this.channel, required this.whatsappMessage});

  final SupportChannelConfig channel;
  final String whatsappMessage;

  @override
  Widget build(BuildContext context) {
    final actionLabel = _channelActionLabel(channel);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSupportChannel(context, channel, whatsappMessage),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _IconBox(
                icon: _channelIcon(channel),
                size: 42,
                iconSize: 22,
                color: _channelColor(channel),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(channel.label, style: _TextStyles.title),
                    const SizedBox(height: 3),
                    Text(actionLabel, style: _TextStyles.body),
                    if (channel.subtitle.trim().isNotEmpty)
                      Text(channel.subtitle, style: _TextStyles.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
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
        _IconBox(icon: icon, size: 38, iconSize: 20, color: _infoColor(icon)),
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
    return _InlineNote(
      icon: Icons.lock_outline_rounded,
      message: message,
      color: OmcPremium.tasks,
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets({
    this.message =
        'No support tickets yet. Submitted tickets will appear here.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InlineNote(
      icon: Icons.inbox_outlined,
      message: message,
      color: OmcPremium.documents,
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
        _InlineNote(
          icon: Icons.cloud_off_outlined,
          message: message,
          color: OmcPremium.danger,
        ),
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
  const _InlineNote({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon, size: 36, iconSize: 19, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: _TextStyles.body)),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    this.size = 40,
    this.iconSize = 21,
    this.color = OmcPremium.system,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, color: color, size: iconSize),
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

Color _topicColor(String iconKey) {
  final key = iconKey.toLowerCase();
  if (key.contains('payment')) return OmcPremium.payments;
  if (key.contains('technical')) return OmcPremium.track;
  if (key.contains('sales')) return OmcPremium.services;
  if (key.contains('pos')) return OmcPremium.leads;
  if (key.contains('tax')) return OmcPremium.tax;
  return OmcPremium.system;
}

IconData _channelIcon(SupportChannelConfig channel) {
  if (channel.isWhatsApp) return Icons.chat_rounded;
  if (channel.isPhone) return Icons.phone_outlined;
  if (channel.isEmail) return Icons.email_outlined;
  return Icons.support_agent_rounded;
}

Color _channelColor(SupportChannelConfig channel) {
  if (channel.isWhatsApp) return OmcPremium.payments;
  if (channel.isPhone) return OmcPremium.track;
  if (channel.isEmail) return OmcPremium.services;
  return OmcPremium.system;
}

Color _priorityColor(SupportTicket ticket) {
  final priority = ticket.priority.trim().toLowerCase();
  if (priority.contains('high') || priority.contains('urgent')) {
    return OmcPremium.danger;
  }
  if (priority.contains('low')) return OmcPremium.track;
  return OmcPremium.tasks;
}

Color _infoColor(IconData icon) {
  if (icon == Icons.schedule_rounded) return OmcPremium.tasks;
  if (icon == Icons.location_on_outlined) return OmcPremium.leads;
  return OmcPremium.system;
}

String _channelActionLabel(SupportChannelConfig channel) {
  if (channel.isWhatsApp) return 'Open WhatsApp chat';
  if (channel.isPhone) return 'Call OMC support';
  if (channel.isEmail) return 'Send email';
  return 'Open support channel';
}

String _topicMessage(SupportTopicConfig topic, String fallbackMessage) {
  final message = topic.defaultMessage.trim();
  if (message.isNotEmpty) return message;

  final fallback = fallbackMessage.trim();
  if (fallback.isNotEmpty) return '$fallback\n\nTopic: ${topic.title}';

  return 'Hello OMC, I need support with ${topic.title}.';
}

Future<void> _openSupportChannel(
  BuildContext context,
  SupportChannelConfig channel,
  String whatsappMessage,
) async {
  final uri = _supportChannelUri(channel, whatsappMessage);
  if (uri == null) {
    _showChannelError(context);
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) _showChannelError(context);
}

Uri? _supportChannelUri(SupportChannelConfig channel, String whatsappMessage) {
  final value = channel.value.trim();
  if (value.isEmpty) return null;

  if (channel.isWhatsApp) {
    final number = _digitsOnly(value);
    if (number.isEmpty) return null;
    final message = whatsappMessage.trim().isNotEmpty
        ? whatsappMessage.trim()
        : 'Hello OMC, I need support.';
    return Uri.https('wa.me', '/$number', {'text': message});
  }

  if (channel.isPhone) {
    return Uri(scheme: 'tel', path: value.replaceAll(' ', ''));
  }

  if (channel.isEmail) {
    return Uri(
      scheme: 'mailto',
      path: value,
      queryParameters: const {'subject': 'OMC support request'},
    );
  }

  final parsed = Uri.tryParse(value);
  return parsed?.hasScheme == true ? parsed : null;
}

String _digitsOnly(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    if (codeUnit >= 48 && codeUnit <= 57) buffer.writeCharCode(codeUnit);
  }
  return buffer.toString();
}

void _showChannelError(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('This support channel could not be opened right now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
