import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return SupportRepository(frappeClient: frappeClient);
});

class SupportRepository {
  const SupportRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<Map<String, dynamic>> createSupportTicket({
    required String topic,
    required String message,
  }) async {
    final cleanTopic = topic.trim();
    final cleanMessage = message.trim();

    if (cleanTopic.isEmpty) {
      throw const ApiError(message: 'Please select a support topic.');
    }

    if (cleanMessage.isEmpty) {
      throw const ApiError(message: 'Please enter support message.');
    }

    return frappeClient.postMethod(
      ApiConfig.createSupportTicketMethod,
      data: {
        'topic': cleanTopic,
        'message': cleanMessage,
        'source': 'mobile_app',
      },
    );
  }
}
