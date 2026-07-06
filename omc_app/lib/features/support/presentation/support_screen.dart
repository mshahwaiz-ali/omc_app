import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/support_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/support_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/support_repository.dart';
import '../data/support_ticket.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedTopic = _SupportCategoriesCard.categories.first.title;
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
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Support',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Get help with services, documents, tax queries and request updates.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          const _SupportHeroCard(),
          const SizedBox(height: 16),
          const _SupportCategoriesCard(),
          const SizedBox(height: 16),
          _CreateSupportTicketCard(
            selectedTopic: _selectedTopic,
            messageController: _messageController,
            isSubmitting: _isSubmitting,
            canSubmit: _canSubmit,
            topics: _SupportCategoriesCard.categories
                .map((category) => category.title)
                .toList(growable: false),
            onTopicChanged: (value) {
              if (value == null) return;
              setState(() => _selectedTopic = value);
            },
            onSubmit: _submitSupportTicket,
          ),
          const SizedBox(height: 16),
          const _SupportTicketsCard(),
          const SizedBox(height: 16),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(
                  title: 'Contact channels',
                  subtitle:
                      'Use direct support options when you need faster help.',
                ),
                const SizedBox(height: 14),
                _SupportTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'WhatsApp support',
                  subtitle: 'Fastest option for service and document queries',
                  onTap: () => SupportLauncher.openWhatsApp(context),
                ),
                const SizedBox(height: 10),
                _SupportTile(
                  icon: Icons.call_outlined,
                  title: 'Call OMC',
                  subtitle: SupportConfig.phoneNumber,
                  onTap: () => SupportLauncher.callSupport(context),
                ),
                const SizedBox(height: 10),
                _SupportTile(
                  icon: Icons.email_outlined,
                  title: 'Email support',
                  subtitle: SupportConfig.email,
                  onTap: () => SupportLauncher.emailSupport(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Business hours',
                  value: SupportConfig.businessHours,
                ),
                SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Office',
                  value: SupportConfig.officeAddress,
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
  const _SupportHeroCard();

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
          const Row(
            children: [
              Expanded(
                child: _SupportMetric(
                  label: 'Tickets',
                  value: 'Tracked',
                  icon: Icons.confirmation_number_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _SupportMetric(
                  label: 'Channels',
                  value: '3 options',
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
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 20),
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
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
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
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: const Row(
        children: [
          Icon(Icons.inbox_outlined, color: AppTheme.textSecondary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No support tickets yet. Submit a request above when you need tracked follow-up.',
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
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(15),
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
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
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
          const Text(
            'Tickets unavailable',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
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
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a support request for tracking and team follow-up.',
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
  const _SupportCategoriesCard();

  static const categories = [
    _SupportCategory(
      icon: Icons.receipt_long_outlined,
      title: 'Income Tax',
      subtitle: 'Returns, NTN, IRIS and filing help',
      message: 'Hello OMC, I need help with an income tax or IRIS matter.',
    ),
    _SupportCategory(
      icon: Icons.point_of_sale_outlined,
      title: 'POS & Digital Invoicing',
      subtitle: 'POS setup, FBR integration and invoices',
      message: 'Hello OMC, I need help with POS or digital invoicing.',
    ),
    _SupportCategory(
      icon: Icons.storefront_outlined,
      title: 'Sales Tax',
      subtitle: 'GST registration and sales tax queries',
      message: 'Hello OMC, I need help with sales tax or GST registration.',
    ),
    _SupportCategory(
      icon: Icons.build_circle_outlined,
      title: 'Technical Support',
      subtitle: 'App, login, upload or tracking issues',
      message: 'Hello OMC, I need technical support for the mobile app.',
    ),
    _SupportCategory(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payment Support',
      subtitle: 'Invoices, receipts and payment follow-up',
      message: 'Hello OMC, I need help with payment or invoice status.',
    ),
  ];

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
          for (final category in categories) ...[
            _SupportCategoryTile(category: category),
            if (category != categories.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SupportCategoryTile extends StatelessWidget {
  const _SupportCategoryTile({required this.category});

  final _SupportCategory category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => SupportLauncher.openWhatsAppWithMessage(
        context,
        message: category.message,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(category.icon, color: AppTheme.primaryRed, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.subtitle,
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

class _SupportCategory {
  const _SupportCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String message;
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
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
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
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
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
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
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
            borderRadius: BorderRadius.circular(15),
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
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
