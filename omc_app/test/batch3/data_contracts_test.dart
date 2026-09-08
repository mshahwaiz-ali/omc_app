import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/network/page_result.dart';
import 'package:omc_app/features/customers/data/customers_repository.dart';
import 'package:omc_app/features/leads/data/leads_repository.dart';
import 'package:omc_app/features/service_catalogue/data/service_catalogue_repository.dart';
import 'package:omc_app/features/service_templates/data/service_template_validation.dart';

class ScriptedClient implements FrappeClient {
  ScriptedClient(this.responses);
  final List<Map<String, dynamic>> responses;
  final queries = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    queries.add({'method': method, ...?queryParameters});
    return {'message': responses.removeAt(0)};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected client method');
}

Map<String, dynamic> detail(int version) => {
  'id': 'SERVICE-A',
  'name': 'SERVICE-A',
  'service_id': 'SERVICE-A',
  'title': 'Service A',
  'category': 'Tax',
  'service_version': version,
  'pricing_version': 'price-$version',
  'base_price': 100,
  'currency': 'PKR',
};
Map<String, dynamic> template(int version) => {
  'service': 'SERVICE-A',
  'form_schema': <dynamic>[],
  'stages': <dynamic>[],
  'service_version': version,
  'pricing_version': 'price-$version',
};

void main() {
  test('authoritative full last page does not invent a next page', () {
    expect(
      readNextStart(
        {'has_more': false, 'next_start': null},
        start: 0,
        count: 50,
        limit: 50,
      ),
      isNull,
    );
  });
  test('valid continuation is retained', () {
    expect(
      readNextStart(
        {'has_more': true, 'next_start': 100},
        start: 50,
        count: 50,
        limit: 50,
      ),
      100,
    );
  });
  test('backwards and skipping continuations are rejected', () {
    for (final next in [0, 49, 51, 100]) {
      expect(
        () => readNextStart(
          {'has_more': true, 'next_start': next},
          start: 0,
          count: 50,
          limit: 50,
        ),
        throwsFormatException,
      );
    }
  });
  test('empty continuing page is rejected', () {
    expect(
      () => readNextStart(
        {'has_more': true, 'next_start': 50},
        start: 0,
        count: 0,
        limit: 50,
      ),
      throwsFormatException,
    );
  });
  test('legacy list supports compatibility but export requires metadata', () {
    expect(readNextStart({}, start: 0, count: 50, limit: 50), 50);
    expect(
      () => readNextStart(
        {},
        start: 0,
        count: 50,
        limit: 50,
        requireMetadata: true,
      ),
      throwsFormatException,
    );
  });
  test(
    'customer list preserves server has_more on a full final page',
    () async {
      final client = ScriptedClient([
        {
          'customers': List.generate(50, (i) => {'name': 'C-$i'}),
          'has_more': false,
          'next_start': null,
        },
      ]);
      final page = await CustomersRepository(
        client,
      ).fetchPage(search: '  12345  ');
      expect(page.items, hasLength(50));
      expect(page.nextStart, isNull);
      expect(client.queries.single['search'], '12345');
      expect(client.queries.single['limit'], 50);
    },
  );
  test(
    'lead list preserves continuation for later-page server search',
    () async {
      final client = ScriptedClient([
        {
          'leads': List.generate(50, (i) => {'name': 'L-$i'}),
          'has_more': true,
          'next_start': 150,
        },
      ]);
      final page = await LeadsRepository(
        client,
      ).fetchPage(start: 100, search: 'older lead');
      expect(page.nextStart, 150);
      expect(client.queries.single['start'], 100);
      expect(client.queries.single['search'], 'older lead');
    },
  );
  test(
    'malformed directory is not misrepresented as an empty directory',
    () async {
      await expectLater(
        CustomersRepository(ScriptedClient([{}])).fetchPage(),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        LeadsRepository(
          ScriptedClient([
            {
              'leads': [42],
            },
          ]),
        ).fetchPage(),
        throwsA(isA<ApiError>()),
      );
    },
  );
  test('explicitly empty authoritative template remains valid', () {
    expect(() => validateServiceTemplate(template(1)), returnsNormally);
  });
  test('malformed rows cannot silently become an empty generic form', () {
    for (final fields in [
      [42],
      [{}],
      [
        {'fieldname': 'x', 'label': 'X'},
      ],
    ]) {
      expect(
        () => validateServiceTemplate({...template(1), 'form_schema': fields}),
        throwsFormatException,
      );
    }
  });
  test('duplicate form fields and invalid flags are rejected', () {
    final field = {
      'fieldname': 'x',
      'label': 'X',
      'fieldtype': 'Data',
      'is_required': 1,
    };
    expect(
      () => validateServiceTemplate({
        ...template(1),
        'form_schema': [field, field],
      }),
      throwsFormatException,
    );
    expect(
      () => validateServiceTemplate({
        ...template(1),
        'form_schema': [
          {...field, 'is_required': 'maybe'},
        ],
      }),
      throwsFormatException,
    );
  });
  test(
    'selected service refreshes a single publication version race',
    () async {
      final client = ScriptedClient([
        detail(1),
        template(2),
        detail(2),
        template(2),
      ]);
      final service = await ServiceCatalogueRepository(
        frappeClient: client,
      ).fetchDetail('SERVICE-A', withTemplate: true);
      expect(service.id, 'SERVICE-A');
      expect(client.queries, hasLength(4));
    },
  );
  test(
    'persistent template version conflict does not recurse or submit',
    () async {
      final client = ScriptedClient([
        detail(1),
        template(2),
        detail(2),
        template(3),
      ]);
      await expectLater(
        ServiceCatalogueRepository(
          frappeClient: client,
        ).fetchDetail('SERVICE-A', withTemplate: true),
        throwsA(isA<ApiError>()),
      );
      expect(client.queries, hasLength(4));
    },
  );
  test('catalogue list uses one request and no template enrichment', () async {
    final client = ScriptedClient([
      {
        'services': [detail(1)],
        'has_more': false,
        'next_start': null,
      },
    ]);
    final page = await ServiceCatalogueRepository(
      frappeClient: client,
    ).fetchPage();
    expect(page.items, hasLength(1));
    expect(client.queries, hasLength(1));
    expect(client.queries.single['lightweight'], 1);
  });
}
