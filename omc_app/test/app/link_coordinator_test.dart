import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/navigation/link_coordinator.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  test('accepts verified and test auth links and rejects foreign hosts', () {
    final coordinator = LinkCoordinator();
    expect(
      coordinator
          .normalize(
            Uri.parse('https://erp.omchouse.com/app/verify-email?token=abc'),
          )
          .toString(),
      '/verify-email?token=abc',
    );
    expect(
      coordinator
          .normalize(Uri.parse('omchouse://auth/reset-password?token=abc'))
          .toString(),
      '/reset-password?token=abc',
    );
    expect(
      coordinator.normalize(
        Uri.parse('https://evil.example/app/verify-email?token=abc'),
      ),
      isNull,
    );
  });

  test('coalesces a pending protected link but allows later redelivery', () {
    final coordinator = LinkCoordinator();
    final link = Uri.parse('/notifications/OMC-NOT-1');

    coordinator.queue(link);
    coordinator.queue(link);

    expect(coordinator.takeFor(AuthStatus.unauthenticated), isNull);
    expect(
      coordinator.takeFor(AuthStatus.authenticated),
      '/notifications/OMC-NOT-1',
    );
    expect(coordinator.takeFor(AuthStatus.authenticated), isNull);

    coordinator.queue(link);

    expect(
      coordinator.takeFor(AuthStatus.authenticated),
      '/notifications/OMC-NOT-1',
    );
  });
}
