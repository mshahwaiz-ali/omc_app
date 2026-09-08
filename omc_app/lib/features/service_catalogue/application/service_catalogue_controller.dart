import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_catalogue_repository.dart';
import '../data/service_item.dart';

final serviceCatalogueProvider = FutureProvider<List<ServiceItem>>((ref) {
  final repository = ref.watch(serviceCatalogueRepositoryProvider);
  return repository.fetchServices();
});

final serviceDetailProvider = FutureProvider.autoDispose.family<List<ServiceItem>, String>((ref, id) async {
  return [await ref.watch(serviceCatalogueRepositoryProvider).fetchDetail(id)];
});
final serviceRequestTemplateProvider = FutureProvider.autoDispose.family<List<ServiceItem>, String>((ref, id) async {
  return [await ref.watch(serviceCatalogueRepositoryProvider).fetchDetail(id, withTemplate: true)];
});
final serviceCataloguePageProvider = FutureProvider.autoDispose.family<ServiceCataloguePage, ({int start, String search, String category})>((ref, query) {
  return ref.watch(serviceCatalogueRepositoryProvider).fetchPage(start: query.start, search: query.search, category: query.category);
});
