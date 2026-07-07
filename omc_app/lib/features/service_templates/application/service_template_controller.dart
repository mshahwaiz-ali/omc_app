import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/service_template.dart';
import '../data/service_template_repository.dart';

final serviceTemplateProvider = FutureProvider.family<ServiceTemplate, String>((
  ref,
  serviceId,
) {
  final repository = ref.watch(serviceTemplateRepositoryProvider);
  return repository.fetchTemplate(serviceId);
});
