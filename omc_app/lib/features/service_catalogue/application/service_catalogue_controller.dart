import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_catalogue_repository.dart';
import '../data/service_item.dart';

final serviceCatalogueProvider = FutureProvider<List<ServiceItem>>((ref) {
  final repository = ref.watch(serviceCatalogueRepositoryProvider);
  return repository.fetchServices();
});
