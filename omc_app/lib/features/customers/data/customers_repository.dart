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

final customerDetailProvider = FutureProvider.family<CustomerItem?, String>((
  ref,
  customerId,
) {
  final repository = ref.watch(customersRepositoryProvider);

  return repository.fetchCustomerDetail(customerId);
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

  Future<CustomerItem?> fetchCustomerDetail(String customerId) async {
    final cleanCustomerId = customerId.trim();
    if (cleanCustomerId.isEmpty) return null;

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.customerDetailMethod,
        queryParameters: {
          'customer_id': cleanCustomerId,
          'name': cleanCustomerId,
        },
      );

      return _mapCustomerDetailResponse(response);
    } on ApiError {
      return null;
    } catch (_) {
      return null;
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

  CustomerItem? _mapCustomerDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawCustomer = message is Map<String, dynamic>
        ? message['customer'] ?? message['data'] ?? message['item'] ?? message
        : data['customer'] ?? data['data'] ?? data['item'];

    if (rawCustomer is! Map<String, dynamic>) return null;

    return CustomerItem.fromJson(rawCustomer);
  }
}
