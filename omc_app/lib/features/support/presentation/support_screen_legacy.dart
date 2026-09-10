import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/app_labeled_field.dart';
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
  final DirtyFormController _dirtyFormController = DirtyFormController();
  String _selectedTopic = '';
  bool _isSubmitting = false;

  bool get _canSubmit =>
      !_isSubmitting &&
      _selectedTopic.isNotEmpty &&
      _messageController.text.trim().length >= 10;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _dirtyFormController.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    if (_messageController.text.trim().isEmpty) {
      _dirtyFormController.markPristine();
    } else {
      _dirtyFormController.markDirty();
    }
    if (mounted) setState(() {});
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
    final isStaff = capabilities.canUseSupportWorkspace;
    final canCreateTicket = capabilities.canCreateSupportTicket;

    if (supportTopics.isNotEmpty &&
        !supportTopics.any((topic) => topic.title == _selectedTopic)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedTopic = supportTopics.first.title);
      });
    }

    return UnsavedChangesGuard(
      controller: _dirtyFormController,
      child: SafeArea(
        child: OmcPageListView(
          topPadding: 18,
          bottomPadding: AppSpacing.xl,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            PremiumListHeader(
              icon: Icons.support_agent_rounded,
              title: isStaff ? 'Support queue' : 'Support',
              subtitle: isStaff
                  ? 'Review customer conversations and take ownership where your role allows.'
                  : canCreateTicket
                  ? 'Track support requests or contact OMC directly.'
                  : 'Contact OMC through the available support channels.',
              metaLabel: isStaff
                  ? 'Internal support workspace'
                  : canCreateTicket
                  ? 'Tracked support available'
                  : 'Direct support',
            ),
            const SizedBox(height: 18),

            if (isStaff) ...[
              _SupportTicketsCard(capabilities: capabilities),
              const SizedBox(height: 14),
              _SupportContactChannelsCard(
                config: supportConfig,
                configError: supportConfigAsync.hasError,
              ),
              const SizedBox(height: 14),
              _SupportTopicsCard(config: supportConfig, topics: supportTopics),
              const SizedBox(height: 14),
              _BackendFaqCard(faqsAsync: faqsAsync),
              const SizedBox(height: 14),
              _SupportLocationCard(config: supportConfig),
            ] else if (canCreateTicket) ...[
              _SupportTicketsCard(capabilities: capabilities),
              const SizedBox(height: 14),
              _CreateSupportTicketCard(
                selectedTopic: _selectedTopic,
                messageController: _messageController,
                isSubmitting: _isSubmitting,
                canSubmit: _canSubmit,
                canCreateTicket: true,
                lockedMessage: '',
                topics: supportTopics
                    .map((topic) => topic.title)
                    .toList(growable: false),
                onTopicChanged: _handleTopicChanged,
                onSubmit: _submitSupportTicket,
              ),
              const SizedBox(height: 14),
              _SupportContactChannelsCard(
                config: supportConfig,
                configError: supportConfigAsync.hasError,
              ),
              const SizedBox(height: 14),
              _SupportTopicsCard(config: supportConfig, topics: supportTopics),
              const SizedBox(height: 14),
              _BackendFaqCard(faqsAsync: faqsAsync),
              const SizedBox(height: 14),
              _SupportLocationCard(config: supportConfig),
            ] else ...[
              _SupportContactChannelsCard(
                config: supportConfig,
                configError: supportConfigAsync.hasError,
              ),
              const SizedBox(height: 14),
              _SupportTopicsCard(config: supportConfig, topics: supportTopics),
              const SizedBox(height: 14),
              _BackendFaqCard(faqsAsync: faqsAsync),
              const SizedBox(height: 14),
              _AccessNote(message: _lockedAccessMessage(capabilities)),
              const SizedBox(height: 14),
              _SupportLocationCard(config: supportConfig),
            ],
          ],
        ),
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
    _dirtyFormController.markDirty();
    setState(() {
      _selectedTopic = value;
      if (_messageController.text.trim().isEmpty &&
          topic.defaultMessage.trim().isNotEmpty) {
        _messageController.text = topic.defaultMessage;
      }
    });
  }

  Future<void> _submitSupportTicket() async {
    if (_isSubmitting) return;

    final capabilities = ref.read(authControllerProvider).capabilities;
    if (!capabilities.canCreateSupportTicket) {
      _showSnack(_lockedAccessMessage(capabilities));
      return;
    }

    final repository = ref.read(supportRepositoryProvider);
    _dirtyFormController.beginSubmitting();
    setState(() => _isSubmitting = true);

    try {
      final activeTicket = await repository.fetchActiveSupportTicket();
      if (!mounted) return;

      if (activeTicket != null && activeTicket.id.trim().isNotEmpty) {
        _dirtyFormController.submissionFailed();
        _showSnack('You already have an active support ticket.');
        context.push(
          '/support-tickets/${Uri.encodeComponent(activeTicket.id)}',
        );
        return;
      }

      await repository.createSupportTicket(
        topic: _selectedTopic,
        message: _messageController.text,
      );
      if (!mounted) return;
      _dirtyFormController.submissionSucceeded();
      setState(_messageController.clear);
      ref.invalidate(supportTicketPageProvider);
      ref.invalidate(supportTicketsProvider);
      ref.invalidate(activeSupportTicketProvider);
      ref.invalidate(supportUnreadCountProvider);
      _showSnack('Support ticket submitted.');
    } on ApiError catch (error) {
      if (!mounted) return;
      _dirtyFormController.submissionFailed();
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _dirtyFormController.submissionFailed();
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Open a new ticket',
            subtitle:
                'Use tracked support when you need an OMC conversation you can return to later.',
          ),
          if (!canCreateTicket) ...[
            const SizedBox(height: 12),
            _AccessNote(message: lockedMessage),
          ],
          const SizedBox(height: 16),
          AppLabeledField(
            label: 'Topic',
            isRequired: true,
            child: DropdownButtonFormField<String>(
              initialValue: topics.contains(selectedTopic)
                  ? selectedTopic
                  : null,
              isExpanded: true,
              items: topics
                  .map(
                    (topic) =>
                        DropdownMenuItem(value: topic, child: Text(topic)),
                  )
                  .toList(growable: false),
              onChanged: canCreateTicket ? onTopicChanged : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.topic_outlined),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppLabeledField(
            label: 'Message',
            isRequired: true,
            child: TextField(
              controller: messageController,
              enabled: canCreateTicket,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'Explain what you need help with…',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canSubmit ? onSubmit : null,
              icon: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSubmitting ? 'Submitting ticket' : 'Submit support ticket',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Messages must contain at least 10 characters.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
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
  final List<SupportTicket> _additionalTickets = [];
  int _selectedTab = 0;
  int? _nextStart;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _didSeedPage = false;
  String? _assigningTicketId;

  bool get _canReadTickets =>
      widget.capabilities.canCreateSupportTicket ||
      widget.capabilities.canUseSupportWorkspace;

  void _resetPagingState() {
    _additionalTickets.clear();
    _nextStart = null;
    _hasMore = false;
    _loadingMore = false;
    _didSeedPage = false;
  }

  List<SupportTicket> _mergeTickets(List<SupportTicket> firstPage) {
    final seen = <String>{};
    final result = <SupportTicket>[];
    for (final ticket in [...firstPage, ..._additionalTickets]) {
      if (seen.add(ticket.id)) result.add(ticket);
    }
    return result;
  }

  void _invalidateSupportSurfaces() {
    ref.invalidate(supportTicketPageProvider);
    ref.invalidate(supportTicketsProvider);
    ref.invalidate(activeSupportTicketProvider);
    ref.invalidate(supportUnreadCountProvider);
  }

  void _refreshTickets() {
    setState(_resetPagingState);
    _invalidateSupportSurfaces();
  }

  Future<void> _loadMore() async {
    final start = _nextStart;
    if (_loadingMore || !_hasMore || start == null) return;

    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .fetchSupportTicketPage(start: start);
      if (!mounted) return;

      final firstPage = ref.read(supportTicketPageProvider).value;
      setState(() {
        final knownIds = <String>{
          ...firstPage?.items.map((ticket) => ticket.id) ?? const <String>[],
          ..._additionalTickets.map((ticket) => ticket.id),
        };
        _additionalTickets.addAll(
          page.items.where((ticket) => knownIds.add(ticket.id)),
        );
        _nextStart = page.nextStart;
        _hasMore = page.hasMore;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('More support tickets could not be loaded.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _assignToMe(SupportTicket ticket) async {
    final authState = ref.read(authControllerProvider);
    final currentUser = authState.userId?.trim() ?? '';
    final canAssign =
        authState.capabilities.canAssignSupportTickets && ticket.canAssign;
    if (!canAssign || ticket.isClosed || currentUser.isEmpty) return;
    if (ticket.isAssignedTo(currentUser)) return;
    if (_assigningTicketId != null) return;

    setState(() => _assigningTicketId = ticket.id);
    try {
      await ref
          .read(supportRepositoryProvider)
          .assignSupportTicket(ticketId: ticket.id, assignedTo: currentUser);
      if (!mounted) return;
      ref.invalidate(supportTicketDetailProvider(ticket.id));
      setState(_resetPagingState);
      _invalidateSupportSurfaces();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket assigned to you.')),
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket assignment could not be updated.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _assigningTicketId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = widget.capabilities;
    if (!_canReadTickets) {
      return _AccessNote(message: _lockedTicketsMessage(capabilities));
    }

    final pageAsync = ref.watch(supportTicketPageProvider);
    final unreadCount = ref.watch(supportUnreadCountProvider).value ?? 0;
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.userId;
    final isInternalQueue = capabilities.canUseSupportWorkspace;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final header = _SectionHeader(
                title: isInternalQueue ? 'Ticket queue' : 'Your tickets',
                subtitle: isInternalQueue
                    ? 'Active customer conversations first; closed tickets remain in history.'
                    : 'Track active support and review closed ticket history.',
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (unreadCount > 0)
                    OmcStatusBadge(
                      label: '$unreadCount unread',
                      color: AppTheme.info,
                    ),
                  IconButton.outlined(
                    onPressed: _refreshTickets,
                    tooltip: 'Refresh tickets',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 10), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          pageAsync.when(
            data: (page) {
              if (!_didSeedPage) {
                _didSeedPage = true;
                _nextStart = page.nextStart;
                _hasMore = page.hasMore;
              }
              final tickets = _mergeTickets(page.items);
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        selected: _selectedTab == 0,
                        showCheckmark: false,
                        label: Text('Active ${activeTickets.length}'),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _selectedTab = 0),
                      ),
                      ChoiceChip(
                        selected: _selectedTab == 1,
                        showCheckmark: false,
                        label: Text('Closed ${closedTickets.length}'),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setState(() => _selectedTab = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (selectedTickets.isEmpty)
                    _InlineNote(
                      icon: Icons.inbox_outlined,
                      message: _selectedTab == 0
                          ? 'No active support tickets right now.'
                          : 'No closed support tickets in the loaded history.',
                      color: AppTheme.textSecondary,
                    )
                  else
                    for (
                      var index = 0;
                      index < selectedTickets.length;
                      index++
                    ) ...[
                      _TicketTile(
                        ticket: selectedTickets[index],
                        showAssignment: isInternalQueue,
                        currentUserId: currentUser,
                        canAssignToMe:
                            capabilities.canAssignSupportTickets &&
                            selectedTickets[index].canAssign &&
                            !selectedTickets[index].isClosed,
                        isAssigning:
                            _assigningTicketId == selectedTickets[index].id,
                        onAssignToMe: () => _assignToMe(selectedTickets[index]),
                      ),
                      if (index != selectedTickets.length - 1)
                        const SizedBox(height: 10),
                    ],
                  if (_hasMore) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loadingMore ? null : _loadMore,
                        icon: _loadingMore
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _loadingMore
                              ? 'Loading tickets'
                              : 'Load more tickets',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorNote(
              message: error is ApiError
                  ? error.message
                  : 'Support tickets could not be loaded right now.',
              onRetry: _refreshTickets,
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

class _TicketTile extends StatelessWidget {
  const _TicketTile({
    required this.ticket,
    required this.showAssignment,
    required this.currentUserId,
    required this.canAssignToMe,
    required this.isAssigning,
    required this.onAssignToMe,
  });

  final SupportTicket ticket;
  final bool showAssignment;
  final String? currentUserId;
  final bool canAssignToMe;
  final bool isAssigning;
  final VoidCallback onAssignToMe;

  @override
  Widget build(BuildContext context) {
    final status = ticket.status.isEmpty ? 'Open' : ticket.status;
    final priority = ticket.priority.isEmpty ? 'Medium' : ticket.priority;
    final assignedToMe = ticket.isAssignedTo(currentUserId);
    final assignmentLabel = assignedToMe
        ? 'Assigned to you'
        : ticket.isAssigned
        ? 'Assigned to ${ticket.assignedTo}'
        : 'Unassigned';

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push('/support-tickets/${Uri.encodeComponent(ticket.id)}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stack =
                      constraints.maxWidth < 350 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                  final identity = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.subject.isEmpty ? ticket.id : ticket.subject,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${ticket.id} · $priority priority',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                  final badge = OmcStatusBadge(label: status);

                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 10), badge],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 12),
                      badge,
                    ],
                  );
                },
              ),
              if (showAssignment) ...[
                const Divider(height: 26),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stack =
                        constraints.maxWidth < 350 ||
                        MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                    final assignment = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          assignedToMe
                              ? Icons.person_pin_circle_rounded
                              : Icons.person_outline_rounded,
                          size: 18,
                          color: assignedToMe
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            assignmentLabel,
                            style: TextStyle(
                              color: assignedToMe
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                    final action = canAssignToMe && !assignedToMe
                        ? TextButton.icon(
                            onPressed: isAssigning ? null : onAssignToMe,
                            icon: isAssigning
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_alt_1_rounded),
                            label: Text(
                              ticket.isAssigned
                                  ? 'Reassign to me'
                                  : 'Assign to me',
                            ),
                          )
                        : null;

                    if (stack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          assignment,
                          if (action != null) ...[
                            const SizedBox(height: 6),
                            action,
                          ],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: assignment),
                        ?action,
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportContactChannelsCard extends StatelessWidget {
  const _SupportContactChannelsCard({
    required this.config,
    required this.configError,
  });

  final SupportConfigData config;
  final bool configError;

  @override
  Widget build(BuildContext context) {
    final channels = [...config.channels]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Direct channels',
            subtitle: 'Choose the quickest available way to contact OMC.',
          ),
          if (configError) ...[
            const SizedBox(height: 10),
            const _InlineNote(
              icon: Icons.cloud_off_outlined,
              message:
                  'Live support configuration could not be refreshed. Available cached or fallback channels are shown below.',
              color: AppTheme.warning,
            ),
          ],
          const SizedBox(height: 14),
          if (channels.isEmpty)
            const _InlineNote(
              icon: Icons.contact_support_outlined,
              message: 'Direct support channels are not available right now.',
              color: AppTheme.textSecondary,
            )
          else
            for (var index = 0; index < channels.length; index++) ...[
              _ChannelTile(
                channel: channels[index],
                whatsappMessage: config.whatsappMessage,
              ),
              if (index != channels.length - 1) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class _SupportTopicsCard extends StatelessWidget {
  const _SupportTopicsCard({required this.config, required this.topics});

  final SupportConfigData config;
  final List<SupportTopicConfig> topics;

  @override
  Widget build(BuildContext context) {
    final sorted = [...topics]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final whatsappChannel = config.whatsappChannel;

    if (sorted.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Support topics',
            subtitle:
                'Open WhatsApp with a ready message for the selected topic.',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < sorted.length && index < 6; index++) ...[
            _TopicRow(
              topic: sorted[index],
              whatsappChannel: whatsappChannel,
              fallbackMessage: config.whatsappMessage,
            ),
            if (index != sorted.length - 1 && index != 5)
              const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _BackendFaqCard extends ConsumerWidget {
  const _BackendFaqCard({required this.faqsAsync});

  final AsyncValue<List<AppFaqItem>> faqsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return faqsAsync.when(
      data: (faqs) {
        final visible = [...faqs]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        if (visible.isEmpty) return const SizedBox.shrink();
        return PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: 'Frequently asked questions',
                subtitle: 'Answers for common OMC support questions.',
              ),
              const SizedBox(height: 8),
              for (final faq in visible.take(5)) _FaqTile(faq: faq),
            ],
          ),
        );
      },
      loading: () => const PremiumCard(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading frequently asked questions…',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
      error: (_, _) => PremiumCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _InlineNote(
              icon: Icons.cloud_off_outlined,
              message: 'Frequently asked questions could not be loaded.',
              color: AppTheme.warning,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(appFaqsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry FAQs'),
            ),
          ],
        ),
      ),
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
      childrenPadding: const EdgeInsets.only(bottom: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        faq.question,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: faq.category == null
          ? null
          : Text(faq.category!, style: const TextStyle(fontSize: 13)),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            faq.answer,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSupportChannel(context, channel, whatsappMessage),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(
              icon: _channelIcon(channel),
              color: _channelColor(channel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _channelActionLabel(channel),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (channel.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      channel.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(
                Icons.open_in_new_rounded,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconBox(
              icon: _topicIcon(topic.iconKey),
              color: _topicColor(topic.iconKey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (topic.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      topic.subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Icon(
                Icons.chat_rounded,
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

class _SupportLocationCard extends StatelessWidget {
  const _SupportLocationCard({required this.config});

  final SupportConfigData config;

  @override
  Widget build(BuildContext context) {
    final businessHours = config.businessHours.trim();
    final office = config.officeAddress.trim();
    if (businessHours.isEmpty && office.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Availability',
            subtitle: 'Business hours and office information from OMC.',
          ),
          if (businessHours.isNotEmpty) ...[
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.schedule_rounded,
              title: 'Business hours',
              value: businessHours,
            ),
          ],
          if (office.isNotEmpty) ...[
            if (businessHours.isNotEmpty) const Divider(height: 24),
            _InfoRow(
              icon: Icons.location_on_outlined,
              title: 'Office',
              value: office,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessNote extends StatelessWidget {
  const _AccessNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: _InlineNote(
        icon: Icons.lock_outline_rounded,
        message: message,
        color: AppTheme.warning,
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
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
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
        _IconBox(icon: icon, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBox(icon: icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
          color: AppTheme.danger,
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

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
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
