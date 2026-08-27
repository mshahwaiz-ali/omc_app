import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/service_catalogue/data/service_catalogue_repository.dart';

void main() {
  test(
    'template enrichment preserves server pricing authority metadata',
    () async {
      final repository = ServiceCatalogueRepository(
        frappeClient: _CatalogueFrappeClient(),
      );

      final services = await repository.fetchServices();

      expect(services, hasLength(1));
      final service = services.single;
      expect(service.formSchema, hasLength(1));
      expect(service.serviceVersion, 7);
      expect(service.pricingVersion, 'server-pricing-hash');
      expect(service.taxPolicy, 'Exclusive');
      expect(service.taxRate, 18);
      expect(service.activationPolicy, 'Full Settlement');
    },
  );
}

class _CatalogueFrappeClient extends FrappeClient {
  _CatalogueFrappeClient()
    : super(
        DioClient(
          secureStorageService: SecureStorageService(),
          dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
        ),
      );

  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (method == ApiConfig.serviceCatalogueMethod) {
      return {
        'message': {
          'services': [
            {
              'id': 'ntn-registration',
              'title': 'NTN Registration',
              'category': 'Tax',
              'fee_label': 'PKR 5,000',
              'completion_time': '3 days',
              'service_version': 7,
              'pricing_version': 'server-pricing-hash',
              'tax_policy': 'Exclusive',
              'tax_rate': 18,
              'activation_policy': 'Full Settlement',
            },
          ],
        },
      };
    }

    expect(method, ApiConfig.serviceTemplateMethod);
    expect(queryParameters, {'service_id': 'ntn-registration'});
    return {
      'message': {
        'service': 'ntn-registration',
        'form_schema': [
          {
            'fieldname': 'active_mobile_number',
            'label': 'Active mobile number',
            'fieldtype': 'Phone',
            'required': true,
          },
        ],
      },
    };
  }
}
