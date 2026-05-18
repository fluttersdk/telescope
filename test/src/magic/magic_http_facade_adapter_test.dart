import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_telescope/src/records/http_request_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Test-only stubs
// ---------------------------------------------------------------------------

/// [NetworkDriver] stub that captures interceptors added via [addInterceptor]
/// so the test can drive them directly without triggering real HTTP.
class _CapturingNetworkDriver implements NetworkDriver {
  final List<MagicNetworkInterceptor> interceptors =
      <MagicNetworkInterceptor>[];

  @override
  void addInterceptor(MagicNetworkInterceptor interceptor) {
    interceptors.add(interceptor);
  }

  // --- required overrides (never called in these tests) ---

  @override
  Future<MagicResponse> get(
    String url, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> put(
    String url, {
    dynamic data,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> delete(
    String url, {
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> upload(
    String url, {
    required Map<String, dynamic> data,
    required Map<String, dynamic> files,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> index(
    String resource, {
    Map<String, dynamic>? filters,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> show(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> store(
    String resource,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> update(
    String resource,
    String id,
    Map<String, dynamic> data, {
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');

  @override
  Future<MagicResponse> destroy(
    String resource,
    String id, {
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError('not used in adapter tests');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Bind a fresh [_CapturingNetworkDriver] in the Magic container and return it.
_CapturingNetworkDriver _bindFakeDriver() {
  final _CapturingNetworkDriver driver = _CapturingNetworkDriver();
  Magic.bind('network', () => driver);
  return driver;
}

/// Build a minimal [MagicRequest].
MagicRequest _req(String url, {String method = 'GET'}) => MagicRequest(
      url: url,
      method: method,
    );

/// Build a successful [MagicResponse].
MagicResponse _ok({int statusCode = 200}) => MagicResponse(
      data: <String, dynamic>{},
      statusCode: statusCode,
    );

/// Build a [MagicError] representing a network-level failure.
MagicError _netError({String message = 'timeout'}) => MagicError(
      message: message,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MagicHttpFacadeAdapter', () {
    late _CapturingNetworkDriver driver;
    late MagicHttpFacadeAdapter adapter;

    setUp(() {
      MagicApp.reset();
      Magic.flush();
      TelescopeStore.resetForTesting();
      driver = _bindFakeDriver();
      adapter = MagicHttpFacadeAdapter();
    });

    tearDown(() {
      TelescopeStore.resetForTesting();
      MagicApp.reset();
      Magic.flush();
    });

    // -------------------------------------------------------------------------
    // (a) install registers _TelescopeNetworkInterceptor on the driver
    // -------------------------------------------------------------------------

    group('install()', () {
      test('registers exactly one interceptor on the network driver', () {
        adapter.install();
        expect(driver.interceptors, hasLength(1));
      });

      test('is a no-op when Magic "network" binding is absent', () {
        // Reset so network is unbound.
        MagicApp.reset();
        Magic.flush();

        final MagicHttpFacadeAdapter unbound = MagicHttpFacadeAdapter();
        expect(() => unbound.install(), returnsNormally);
      });
    });

    // -------------------------------------------------------------------------
    // (b) onRequest pushes request onto the FIFO pending queue
    //     observable only via subsequent onResponse producing a record
    // -------------------------------------------------------------------------

    group('onRequest / onResponse pairing', () {
      test(
          'onRequest followed by onResponse emits one HttpRequestRecord to '
          'TelescopeStore.onHttpRecord', () async {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        final List<HttpRequestRecord> received = <HttpRequestRecord>[];
        final subscription = TelescopeStore.onHttpRecord.listen(received.add);

        // 1. Simulate request phase.
        interceptor.onRequest(_req('/monitors', method: 'GET'));

        // 2. Simulate response phase ; triggers StreamController.add.
        interceptor.onResponse(_ok());

        // Flush microtask queue so broadcast stream delivers to listener.
        await Future<void>.microtask(() {});

        expect(received, hasLength(1));
        expect(received.first.url, '/monitors');
        expect(received.first.method, 'GET');
        expect(received.first.statusCode, 200);
        expect(received.first.isError, isFalse);

        await subscription.cancel();
      });

      test(
          'record is also present in TelescopeStore.recentHttp after '
          'onResponse', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        interceptor.onRequest(_req('/status'));
        interceptor.onResponse(_ok(statusCode: 201));

        final List<HttpRequestRecord> records = TelescopeStore.recentHttp();
        expect(records, hasLength(1));
        expect(records.first.statusCode, 201);
      });
    });

    // -------------------------------------------------------------------------
    // (c) onResponse pops the matching request (FIFO) and emits the record
    // -------------------------------------------------------------------------

    group('FIFO attribution', () {
      test(
          'two sequential requests are matched in insertion order '
          '(attributedHeuristically: true on both)', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        // 1. Enqueue two requests.
        interceptor.onRequest(_req('/a'));
        interceptor.onRequest(_req('/b'));

        // 2. Resolve in FIFO order.
        interceptor.onResponse(_ok(statusCode: 200));
        interceptor.onResponse(_ok(statusCode: 201));

        final List<HttpRequestRecord> records = TelescopeStore.recentHttp();
        expect(records, hasLength(2));

        // First response attributed to /a, second to /b.
        expect(records[0].url, '/a');
        expect(records[0].statusCode, 200);
        expect(records[0].attributedHeuristically, isTrue);

        expect(records[1].url, '/b');
        expect(records[1].statusCode, 201);
        expect(records[1].attributedHeuristically, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // (d) onError attributes the error to the pending request
    // -------------------------------------------------------------------------

    group('onError', () {
      test(
          'onError produces an isError record attributed to the pending request',
          () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        interceptor.onRequest(_req('/fail', method: 'POST'));
        interceptor.onError(_netError(message: 'connection refused'));

        final List<HttpRequestRecord> records = TelescopeStore.recentHttp();
        expect(records, hasLength(1));
        expect(records.first.url, '/fail');
        expect(records.first.method, 'POST');
        expect(records.first.isError, isTrue);
        expect(records.first.responseBody, 'connection refused');
      });

      test('onError when pending queue is empty does not push a record', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        // No preceding onRequest; queue is empty.
        interceptor.onError(_netError());

        expect(TelescopeStore.recentHttp(), isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // (e) uninstall disarms the interceptor (recording becomes a no-op)
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('after uninstall, onResponse no longer emits records', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        // Enqueue one request and then disarm.
        interceptor.onRequest(_req('/before-uninstall'));
        adapter.uninstall();

        // Response arrives after uninstall.
        interceptor.onResponse(_ok());

        expect(TelescopeStore.recentHttp(), isEmpty);
      });

      test('after uninstall, onError no longer emits records', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        interceptor.onRequest(_req('/before-uninstall'));
        adapter.uninstall();

        interceptor.onError(_netError());

        expect(TelescopeStore.recentHttp(), isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // (f) two concurrent requests ; FIFO pairing + attributedHeuristically
    // -------------------------------------------------------------------------

    group('concurrent FIFO pairing', () {
      test(
          'responses for two concurrent in-flight requests are attributed '
          'heuristically in FIFO order; attributedHeuristically is true', () {
        adapter.install();
        final MagicNetworkInterceptor interceptor = driver.interceptors.first;

        // 1. Both requests enter before any response arrives.
        interceptor.onRequest(_req('/concurrent-1', method: 'GET'));
        interceptor.onRequest(_req('/concurrent-2', method: 'DELETE'));

        // 2. First response resolves against /concurrent-1 (FIFO head).
        interceptor.onResponse(_ok(statusCode: 200));

        // 3. Second response resolves against /concurrent-2.
        interceptor.onResponse(_ok(statusCode: 204));

        final List<HttpRequestRecord> records = TelescopeStore.recentHttp();
        expect(records, hasLength(2));

        expect(records[0].url, '/concurrent-1');
        expect(records[0].method, 'GET');
        expect(records[0].statusCode, 200);
        expect(records[0].attributedHeuristically, isTrue);

        expect(records[1].url, '/concurrent-2');
        expect(records[1].method, 'DELETE');
        expect(records[1].statusCode, 204);
        expect(records[1].attributedHeuristically, isTrue);
      });
    });
  });
}
