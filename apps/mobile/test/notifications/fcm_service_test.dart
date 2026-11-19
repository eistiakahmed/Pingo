import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/services/fcm_service.dart';

/// Covers FcmService.initialize() concurrency/retry semantics.
///
/// In the test environment the Firebase platform channels are unmocked,
/// so Firebase.initializeApp() deterministically fails. This exercises the
/// failure path (error rethrow + guard reset) without Firebase mocking.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initialize() shares one attempt across concurrent callers '
    'and retries after a failed attempt',
    () async {
      final first = FcmService.instance.initialize();
      final concurrent = FcmService.instance.initialize();

      // Concurrent callers must share the exact same in-flight init future.
      expect(
        identical(first, concurrent),
        isTrue,
        reason: 'concurrent initialize() callers must share one init run',
      );

      // Initialization fails on unmocked platform channels; the error must
      // be observable to callers (not swallowed).
      await expectLater(first, throwsA(anything));

      // A failed attempt must not be cached: the next call starts a fresh run.
      final retry = FcmService.instance.initialize();
      expect(
        identical(first, retry),
        isFalse,
        reason: 'a failed init attempt must not be returned to later callers',
      );
      await expectLater(retry, throwsA(anything));
    },
  );
}
