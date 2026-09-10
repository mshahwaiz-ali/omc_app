from pathlib import Path

path = Path('omc_app/lib/features/support/presentation/support_screen_legacy.dart')
text = path.read_text()

anchor = "import '../../../core/widgets/omc_premium.dart';\n"
new_import = "import '../../../core/widgets/app_labeled_field.dart';\n"
if new_import not in text:
    if text.count(anchor) != 1:
        raise SystemExit('support import anchor mismatch')
    text = text.replace(anchor, anchor + new_import, 1)

start = text.index('class _CreateSupportTicketCard')
end = text.index('class _SupportTicketsCard', start)
block = text[start:end]

old = """    return PremiumCard(\n      padding: const EdgeInsets.all(18),"""
new = """    return PremiumCard(\n      padding: const EdgeInsets.all(AppSpacing.lg),"""
if block.count(old) != 1:
    raise SystemExit('support card padding anchor mismatch')
block = block.replace(old, new, 1)

old = """          DropdownButtonFormField<String>(\n            initialValue: topics.contains(selectedTopic) ? selectedTopic : null,\n            isExpanded: true,\n            items: topics\n                .map(\n                  (topic) => DropdownMenuItem(value: topic, child: Text(topic)),\n                )\n                .toList(growable: false),\n            onChanged: canCreateTicket ? onTopicChanged : null,\n            decoration: const InputDecoration(\n              labelText: 'Topic',\n              prefixIcon: Icon(Icons.topic_outlined),\n            ),\n          ),\n          const SizedBox(height: 12),\n          TextField(\n            controller: messageController,\n            enabled: canCreateTicket,\n            minLines: 4,\n            maxLines: 7,\n            style: const TextStyle(fontSize: 16),\n            decoration: const InputDecoration(\n              labelText: 'Message',\n              hintText: 'Explain what you need help with…',\n              alignLabelWithHint: true,\n              prefixIcon: Icon(Icons.message_outlined),\n            ),\n          ),"""
new = """          AppLabeledField(\n            label: 'Topic',\n            isRequired: true,\n            child: DropdownButtonFormField<String>(\n              initialValue: topics.contains(selectedTopic) ? selectedTopic : null,\n              isExpanded: true,\n              items: topics\n                  .map(\n                    (topic) => DropdownMenuItem(value: topic, child: Text(topic)),\n                  )\n                  .toList(growable: false),\n              onChanged: canCreateTicket ? onTopicChanged : null,\n              decoration: const InputDecoration(\n                prefixIcon: Icon(Icons.topic_outlined),\n              ),\n            ),\n          ),\n          const SizedBox(height: AppSpacing.lg),\n          AppLabeledField(\n            label: 'Message',\n            isRequired: true,\n            child: TextField(\n              controller: messageController,\n              enabled: canCreateTicket,\n              minLines: 4,\n              maxLines: 7,\n              decoration: const InputDecoration(\n                hintText: 'Explain what you need help with…',\n                alignLabelWithHint: true,\n                prefixIcon: Icon(Icons.message_outlined),\n              ),\n            ),\n          ),"""
if block.count(old) != 1:
    raise SystemExit('support ticket fields anchor mismatch')
block = block.replace(old, new, 1)

old = """          const SizedBox(height: 7),\n          const Text(\n            'Messages must contain at least 10 characters.',\n            style: TextStyle(\n              color: AppTheme.textSecondary,\n              fontSize: 13,\n              height: 1.35,\n            ),\n          ),"""
new = """          const SizedBox(height: 6),\n          Text(\n            'Messages must contain at least 10 characters.',\n            style: Theme.of(context).textTheme.bodyMedium?.copyWith(\n              color: AppTheme.textSecondary,\n            ),\n          ),"""
if block.count(old) != 1:
    raise SystemExit('support helper anchor mismatch')
block = block.replace(old, new, 1)

text = text[:start] + block + text[end:]
path.write_text(text)

test = Path('omc_app/test/features/support/support_uiux_contract_test.dart')
test.parent.mkdir(parents=True, exist_ok=True)
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routed support wrapper still renders the legacy implementation', () {
    final wrapper = File(
      'lib/features/support/presentation/support_screen.dart',
    ).readAsStringSync();
    expect(wrapper, contains('const Expanded(child: legacy.SupportScreen())'));
  });

  test('live support ticket form uses persistent V2 field labels', () {
    final source = File(
      'lib/features/support/presentation/support_screen_legacy.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _CreateSupportTicketCard');
    final end = source.indexOf('class _SupportTicketsCard', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);

    expect(block, contains("AppLabeledField(\n            label: 'Topic'"));
    expect(block, contains("AppLabeledField(\n            label: 'Message'"));
    expect(block, contains('isRequired: true'));
    expect(block, isNot(contains("labelText: 'Topic'")));
    expect(block, isNot(contains("labelText: 'Message'")));
    expect(block, contains('padding: const EdgeInsets.all(AppSpacing.lg)'));
    expect(block, contains('textTheme.bodyMedium'));
    expect(block, isNot(contains('fontSize: 13')));
    expect(block, contains('_selectedTopic.isNotEmpty'));
    expect(block, contains('_messageController.text.trim().length >= 10'));
  });
}
''')
