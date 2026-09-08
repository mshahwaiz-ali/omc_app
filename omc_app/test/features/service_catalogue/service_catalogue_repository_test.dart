import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/service_catalogue/data/service_catalogue_repository.dart';

void main() {
  test(
    'direct request loads a verified template independently of catalogue',
    () async {
      final client = _CatalogueFrappeClient();
      final service = await ServiceCatalogueRepository(
        frappeClient: client,
      ).fetchDetail('ntn-registration', withTemplate: true);
      expect(service.formSchema, hasLength(1));
      expect(client.calls, [
        ApiConfig.serviceDetailMethod,
        ApiConfig.serviceTemplateMethod,
      ]);
    },
  );
  test(
    'template failure propagates instead of returning a generic form',
    () async {
      final client = _CatalogueFrappeClient()..failTemplate = true;
      await expectLater(
        ServiceCatalogueRepository(
          frappeClient: client,
        ).fetchDetail('ntn-registration', withTemplate: true),
        throwsA(isA<Exception>()),
      );
    },
  );

  test('catalogue stays lightweight and preserves pricing metadata', () async {
    final repository = ServiceCatalogueRepository(
      frappeClient: _CatalogueFrappeClient(),
    );

    final services = await repository.fetchServices();

    expect(services, hasLength(1));
    final service = services.single;
    expect(service.formSchema, isEmpty);
    expect(service.serviceVersion, 7);
    expect(service.pricingVersion, 'server-pricing-hash');
    expect(service.taxPolicy, 'Exclusive');
    expect(service.taxRate, 18);
    expect(service.activationPolicy, 'Full Settlement');
  });
}

class _CatalogueFrappeClient extends FrappeClient {
  final calls = <String>[];
  bool failTemplate = false;
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
    calls.add(method);
    if (method == ApiConfig.serviceDetailMethod) {
      return {
        'message': {
          'id': 'ntn-registration',
          'title': 'NTN Registration',
          'service_version': 7,
          'pricing_version': 'server-pricing-hash',
        },
      };
    }
    if (method == ApiConfig.serviceCatalogueMethod) {
      expect(queryParameters?['lightweight'], 1);
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
    if (failTemplate) throw Exception("unavailable");
    expect(queryParameters, {'service_id': 'ntn-registration'});
    return {
      'message': {
        'service': 'ntn-registration',
        'service_version': 7,
        'pricing_version': 'server-pricing-hash',
        'stages': [],
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
