import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/push/push_destination.dart';
import 'package:omc_app/core/push/push_registration.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/features/notifications/data/notifications_repository.dart';

const binding = '0123456789abcdef0123456789abcdef';
const customer = AuthCapabilities(
  accessState: AccountAccessState.approved,
  canTrackRequests: true,
  canViewDocuments: true,
  canViewPayments: true,
  canCreateSupportTicket: true,
  canViewCustomerNotifications: true,
);
AuthState signedIn(String user) => AuthState.authenticated(
  userId: user,
  canAccessInternalWorkspace: false,
  capabilities: customer,
);

class FakeSource implements BoundPushTokenSource {
  String? binding;
  Future<String?> Function()? acquire;
  PushPermission permission = PushPermission.granted;
  final refresh = StreamController<String>.broadcast();
  final opens = StreamController<PushOpenIntent>.broadcast();
  @override
  bool get ready => true;
  @override
  String? get bindingId => binding;
  @override
  PushOpenIntent? pendingOpen;
  @override
  String get platform => 'android';
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> requestToken() => acquire?.call() ?? Future.value('TOKEN');
  @override
  Stream<String> get tokenRefreshes => refresh.stream;
  @override
  Stream<String> get openedRoutes => const Stream.empty();
  @override
  Stream<PushOpenIntent> get openedNotifications => opens.stream;
  @override
  Future<PushPermission> permissionState() async => permission;
  @override
  Future<void> enableNotifications() async {}
  @override
  void setBinding(String? value) => binding = value;
  @override
  void clearPending() => pendingOpen = null;
  @override
  void consumeOpen(PushOpenIntent intent) {
    if (pendingOpen == intent) pendingOpen = null;
  }

  @override
  Future<void> resetDevice() async {
    binding = null;
    pendingOpen = null;
  }

  @override
  void dispose() {
    unawaited(refresh.close());
    unawaited(opens.close());
  }
}

class FakeClient implements FrappeClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('notification repository exposes the provider constructor contract', () {
    expect(
      NotificationsRepository(frappeClient: FakeClient()),
      isA<NotificationsRepository>(),
    );
  });
  test(
    'opaque intent rejects missing, malformed and control-character IDs',
    () {
      expect(
        PushOpenIntent.fromData({
          'notification_id': 'N-1',
          'binding_id': binding,
        }),
        const PushOpenIntent('N-1', binding),
      );
      for (final data in [
        {'notification_id': 'N-1', 'binding_id': 'wrong'},
        {'notification_id': ' N-1', 'binding_id': binding},
        {'notification_id': 'N\n1', 'binding_id': binding},
        {'route': 'https://example.invalid'},
      ]) {
        expect(PushOpenIntent.fromData(data), isNull);
      }
    },
  );
  test(
    'customer routes derive from authoritative references, not supplied URLs',
    () {
      for (final pair in {
        'OMC Service Request': '/my-services/R-1',
        'OMC Service Document': '/documents/R-1',
        'OMC Service Payment': '/payments/R-1',
        'OMC Support Ticket': '/support-tickets/R-1',
      }.entries) {
        expect(
          pushDestination({
            'name': 'N-1',
            'reference_doctype': pair.key,
            'reference_name': 'R-1',
            'mobile_route': 'https://example.invalid',
          }, customer),
          pair.value,
        );
      }
      expect(
        pushDestination({
          'name': 'N-1',
          'reference_doctype': '',
          'mobile_route': '/admin-control',
        }, customer),
        '/notifications/N-1',
      );
    },
  );
  test(
    'Task and internal service routes enforce existing capability policy',
    () {
      final task = {
        'name': 'N-1',
        'reference_doctype': 'Task',
        'reference_name': 'T-1',
      };
      expect(pushDestination(task, customer), isNull);
      const staff = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canViewTasks: true,
        canViewAllServiceCases: true,
        canAccessInternalWorkspace: true,
      );
      expect(pushDestination(task, staff), '/tasks/T-1');
      expect(
        pushDestination({
          'reference_doctype': 'OMC Service Request',
          'reference_name': 'R-1',
        }, staff),
        '/internal-workspace/service-cases/R-1',
      );
    },
  );
  test(
    'unknown target does not navigate and reference names are URI encoded',
    () {
      expect(
        pushDestination({
          'reference_doctype': 'User',
          'reference_name': 'Administrator',
        }, customer),
        isNull,
      );
      expect(
        pushDestination({
          'reference_doctype': 'OMC Service Document',
          'reference_name': 'A/B?C',
        }, customer),
        '/documents/A%2FB%3FC',
      );
    },
  );

  group('authenticated token lifecycle', () {
    late FakeSource source;
    late String? owner;
    late List<Map<String, dynamic>> requests;
    late PushRegistrationCoordinator coordinator;
    setUp(() {
      source = FakeSource();
      owner = 'a@example.test';
      requests = [];
      coordinator = PushRegistrationCoordinator(
        source: source,
        currentOwner: () => owner,
        installationId: () async => binding,
        mutate: (method, data, cancellation) async {
          requests.add({'method': method, ...data});
          return {'registered': true, 'binding_id': binding};
        },
      );
    });
    tearDown(() {
      coordinator.dispose();
      source.dispose();
    });

    test(
      'registers installation and captures canonical server binding',
      () async {
        await coordinator.syncForAuth(signedIn(owner!));
        expect(source.bindingId, binding);
        expect(coordinator.status.value.registered, isTrue);
        expect(requests.single['device_id'], binding);
      },
    );
    test('unauthenticated users do not request backend registration', () async {
      owner = null;
      await coordinator.syncForAuth(const AuthState.unauthenticated());
      expect(requests, isEmpty);
    });
    test(
      'logout unregisters the expected binding and clears local authority',
      () async {
        await coordinator.syncForAuth(signedIn(owner!));
        final cleanup = coordinator.prepareForSignOut();
        expect(source.bindingId, isNull);
        expect(coordinator.owner, isNull);
        owner = null;
        await cleanup;
        expect(requests.last['method'], ApiConfig.unregisterPushTokenMethod);
        expect(requests.last['binding_id'], binding);
      },
    );
    test('late token acquisition after logout cannot register', () async {
      final token = Completer<String?>();
      source.acquire = () => token.future;
      final work = coordinator.syncForAuth(signedIn(owner!));
      await Future<void>.delayed(Duration.zero);
      final cleanup = coordinator.prepareForSignOut();
      owner = null;
      token.complete('LATE');
      await Future.wait([work, cleanup]);
      expect(requests, isEmpty);
      expect(source.bindingId, isNull);
    });
  });

  test(
    'late registration response is cancelled and cannot restore binding',
    () async {
      final source = FakeSource();
      String? owner = 'a@example.test';
      final entered = Completer<void>();
      final response = Completer<Map<String, dynamic>>();
      late CancelToken token;
      final coordinator = PushRegistrationCoordinator(
        source: source,
        currentOwner: () => owner,
        installationId: () async => binding,
        mutate: (method, data, cancellation) {
          token = cancellation;
          entered.complete();
          return response.future;
        },
      );
      addTearDown(() {
        coordinator.dispose();
        source.dispose();
      });
      final work = coordinator.syncForAuth(signedIn('a@example.test'));
      await entered.future;
      final cleanup = coordinator.prepareForSignOut();
      owner = null;
      response.complete({'registered': true, 'binding_id': binding});
      await Future.wait([work, cleanup]);
      expect(token.isCancelled, isTrue);
      expect(source.bindingId, isNull);
    },
  );

  test(
    'network timeout cancels request without failing the login session',
    () async {
      final source = FakeSource();
      late CancelToken token;
      final coordinator = PushRegistrationCoordinator(
        source: source,
        currentOwner: () => 'a@example.test',
        installationId: () async => binding,
        requestDeadline: const Duration(milliseconds: 5),
        mutate: (method, data, cancellation) {
          token = cancellation;
          return Completer<Map<String, dynamic>>().future;
        },
      );
      addTearDown(() {
        coordinator.dispose();
        source.dispose();
      });
      await coordinator.syncForAuth(signedIn('a@example.test'));
      expect(token.isCancelled, isTrue);
      expect(coordinator.status.value.retryNeeded, isTrue);
      expect(coordinator.owner, 'a@example.test');
    },
  );
}
