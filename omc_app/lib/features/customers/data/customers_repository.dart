import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/customer_item.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return CustomersRepository(frappeClient);
});

final customersProvider = FutureProvider<List<CustomerItem>>((ref) {
  final repository = ref.watch(customersRepositoryProvider);

  return repository.fetchCustomers();
});

class CustomersRepository {
  const CustomersRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<CustomerItem>> fetchCustomers() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.customersMethod);

      return _mapCustomersResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<CustomerItem> _mapCustomersResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawCustomers = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['customers'] ?? message['data'] ?? message['items']
        : data['customers'] ?? data['data'] ?? data['items'];

    if (rawCustomers is! List) return const [];

    return rawCustomers
        .whereType<Map<String, dynamic>>()
        .map(CustomerItem.fromJson)
        .toList(growable: false);
  }
}
