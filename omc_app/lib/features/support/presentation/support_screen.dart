import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/support_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_list_header.dart';
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
    final supportConfig = supportConfigAsync.value ?? SupportConfigData.fallback;
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
            canSubmit: _canSubmit,
            topics: supportTopics.map((topic) => topic.title).toList(growable: false),
            onTopicChanged: (value) {
              if (value == null) return;
              final topic = supportTopics.firstWhere(
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
            },
            onSubmit: _submitSupportTicket,
          ),
          const SizedBox(height: 16),
          const _SupportTicketsCard(),
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

  Future<void> _submitSupportTicket() async {
    final repository = ref.read(supportRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    try {
      await repository.createSupportTicket(
        topic: _selectedTopic,
        message: _messageController.text,
      );

      if (!mounted) return;

      setState(() {
        _messageController.clear();
      });
      ref.invalidate(supportTicketsProvider);

      messenger.showSnackBar(
        const SnackBar(content: Text('Support ticket submitted.')),
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Support ticket could not be submitted right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
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
          const Text(
            'How can we help?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a tracked ticket or contact OMC directly for service, document, tax and payment support.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SupportTicketsCard extends ConsumerWidget {
  const _SupportTicketsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (tickets.isEmpty) {
                return const _EmptySupportTicketsView();
              }

              final visibleTickets = tickets.take(5).toList(growable: false);

              return Column(
                children: [
                  for (
                    var index = 0;
                    index < visibleTickets.length;
                    index++
                  ) ...[
                    _SupportTicketTile(ticket: visibleTickets[index]),
                    if (index != visibleTickets.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              );
            },
            loading: () => const _SupportTicketsLoadingView(),
            error: (error, _) => _SupportTicketsErrorView(
              message: _cleanSupportError(error),
              onRetry: () => ref.invalidate(supportTicketsProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTicketTile extends StatelessWidget {
  const _SupportTicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push('/support-tickets/${Uri.encodeComponent(ticket.id)}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: AppTheme.primaryRed,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ticket.status} • ${ticket.priority}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (ticket.updatedAtLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      ticket.updatedAtLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySupportTicketsView extends StatelessWidget {
  const _EmptySupportTicketsView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: AppTheme.primaryRed,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No support tickets yet. Submit a request above when you need tracked follow-up.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTicketsLoadingView extends StatelessWidget {
  const _SupportTicketsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.only(bottom: index == 2 ? 0 : 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 150,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTicketsErrorView extends StatelessWidget {
  const _SupportTicketsErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.primaryRed,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tickets unavailable',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

String _cleanSupportError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Support tickets could not be loaded right now.';
  }
  return message;
}

class _CreateSupportTicketCard extends StatelessWidget {
  const _CreateSupportTicketCard({
    required this.selectedTopic,
    required this.messageController,
    required this.isSubmitting,
    required this.canSubmit,
    required this.topics,
    required this.onTopicChanged,
    required this.onSubmit,
  });

  final String selectedTopic;
  final TextEditingController messageController;
  final bool isSubmitting;
  final bool canSubmit;
  final List<String> topics;
  final ValueChanged<String?> onTopicChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create support ticket',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a support request for tracking and team follow-up.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: selectedTopic,
            items: topics
                .map(
                  (topic) => DropdownMenuItem<String>(
                    value: topic,
                    child: Text(topic),
                  ),
                )
                .toList(growable: false),
            onChanged: isSubmitting ? null : onTopicChanged,
            decoration: const InputDecoration(
              labelText: 'Topic',
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: messageController,
            enabled: !isSubmitting,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Describe the issue or support request',
              helperText: 'Minimum 10 characters required.',
              prefixIcon: Icon(Icons.message_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: isSubmitting ? 'Submitting...' : 'Submit ticket',
            icon: Icons.send_rounded,
            onPressed: canSubmit ? onSubmit : null,
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
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose a support topic',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start with the right context so OMC can route your query faster.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final topic in topics) ...[
            _SupportCategoryTile(topic: topic),
            if (topic != topics.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SupportCategoryTile extends StatelessWidget {
  const _SupportCategoryTile({required this.topic});

  final SupportTopicConfig topic;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => SupportLauncher.openWhatsAppWithMessage(
        context,
        message: topic.defaultMessage.trim().isNotEmpty
            ? topic.defaultMessage
            : 'Hello OMC, I need help with ${topic.title}.',
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(_supportTopicIcon(topic.iconKey), color: AppTheme.primaryRed, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topic.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppTheme.primaryRed,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportContactChannelsCard extends StatelessWidget {
  const _SupportContactChannelsCard({required this.config});

  final SupportConfigData config;

  @override
  Widget build(BuildContext context) {
    final channels = config.channels.isNotEmpty
        ? config.channels
        : SupportConfigData.fallback.channels;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Contact channels',
            subtitle: 'Use direct support options when you need faster help.',
          ),
          const SizedBox(height: 14),
          for (final channel in channels) ...[
            _SupportTile(
              icon: _supportChannelIcon(channel),
              title: channel.label,
              subtitle: channel.subtitle.trim().isNotEmpty
                  ? channel.subtitle
                  : channel.value,
              onTap: () => _openChannel(context, channel, config),
            ),
            if (channel != channels.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _openChannel(
    BuildContext context,
    SupportChannelConfig channel,
    SupportConfigData config,
  ) {
    if (channel.isWhatsApp) {
      SupportLauncher.openWhatsApp(
        context,
        phoneNumber: channel.value,
        message: config.whatsappMessage,
      );
      return;
    }

    if (channel.isPhone) {
      SupportLauncher.callSupport(context, phoneNumber: channel.value);
      return;
    }

    if (channel.isEmail) {
      SupportLauncher.emailSupport(context, email: channel.value);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${channel.label}: ${channel.value}')),
    );
  }
}

IconData _supportTopicIcon(String iconKey) {
  switch (iconKey.trim().toLowerCase()) {
    case 'tax':
    case 'income_tax':
      return Icons.receipt_long_outlined;
    case 'pos':
    case 'invoice':
    case 'digital_invoice':
      return Icons.point_of_sale_outlined;
    case 'sales_tax':
    case 'gst':
      return Icons.storefront_outlined;
    case 'technical':
    case 'app':
      return Icons.build_circle_outlined;
    case 'payment':
      return Icons.account_balance_wallet_outlined;
    default:
      return Icons.support_agent_rounded;
  }
}

IconData _supportChannelIcon(SupportChannelConfig channel) {
  if (channel.isWhatsApp) return Icons.chat_bubble_outline_rounded;
  if (channel.isPhone) return Icons.call_outlined;
  if (channel.isEmail) return Icons.email_outlined;
  return Icons.support_agent_rounded;
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryRed.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(icon, color: AppTheme.primaryRed, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
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
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(icon, color: AppTheme.primaryRed, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
