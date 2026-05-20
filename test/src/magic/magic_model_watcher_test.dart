@Tags(['magic'])
library;

// flutter_test re-exports its own `EventDispatcher` (for pointer events)
// via test_pointer.dart; hide it so the magic-side dispatcher resolves
// unambiguously below.
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:fluttersdk_telescope/src/records/magic_model_record.dart';
import 'package:fluttersdk_telescope/src/telescope_store.dart';
import 'package:magic/magic.dart';

/// Minimal concrete [Model] for watcher tests (no persistence surface).
class _FakeModel extends Model {
  _FakeModel({String? id, Map<String, dynamic>? attrs}) {
    if (id != null) setAttribute('id', id);
    if (attrs != null) {
      for (final MapEntry<String, dynamic> entry in attrs.entries) {
        setAttribute(entry.key, entry.value);
      }
    }
  }

  @override
  String get table => 'fakes';

  @override
  String get resource => 'fakes';
}

void main() {
  group('MagicModelWatcher', () {
    late MagicModelWatcher watcher;

    setUp(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
      watcher = MagicModelWatcher();
    });

    tearDown(() {
      EventDispatcher.instance.clear();
      TelescopeStore.resetForTesting();
    });

    // -------------------------------------------------------------------------
    // (f) name getter
    // -------------------------------------------------------------------------

    test('name returns "magic_model"', () {
      expect(watcher.name, 'magic_model');
    });

    // -------------------------------------------------------------------------
    // (a) install registers listener factories for ModelCreated/Saved/Deleted
    // (b) firing each event triggers TelescopeStore.recordMagicModel with
    //     the correct event tag
    // -------------------------------------------------------------------------

    group('install() subscriptions', () {
      test('ModelCreated fires a record with event tag "created"', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));

        final List<MagicModelRecord> models = TelescopeStore.recentModels();
        expect(models, hasLength(1));
        expect(models.first.event, 'created');
      });

      test('ModelSaved fires a record with event tag "saved"', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelSaved(_FakeModel()));

        final List<MagicModelRecord> models = TelescopeStore.recentModels();
        expect(models, hasLength(1));
        expect(models.first.event, 'saved');
      });

      test('ModelDeleted fires a record with event tag "deleted"', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelDeleted(_FakeModel()));

        final List<MagicModelRecord> models = TelescopeStore.recentModels();
        expect(models, hasLength(1));
        expect(models.first.event, 'deleted');
      });

      test('each of the three event types is independently subscribed',
          () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));
        await EventDispatcher.instance.dispatch(ModelSaved(_FakeModel()));
        await EventDispatcher.instance.dispatch(ModelDeleted(_FakeModel()));

        final List<MagicModelRecord> models = TelescopeStore.recentModels();
        expect(models, hasLength(3));
        expect(models.map((r) => r.event),
            containsAll(<String>['created', 'saved', 'deleted']));
      });
    });

    // -------------------------------------------------------------------------
    // (c) the recorded MagicModelRecord captures modelClass, modelKey, and
    //     model attributes via the listener
    // -------------------------------------------------------------------------

    group('MagicModelRecord payload', () {
      test('modelClass is the runtime type of the dispatched model', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));

        final MagicModelRecord record = TelescopeStore.recentModels().first;
        expect(record.modelClass, '_FakeModel');
      });

      test('modelKey captures model id when present', () async {
        watcher.install();
        final _FakeModel model = _FakeModel(id: 'abc-123');

        await EventDispatcher.instance.dispatch(ModelCreated(model));

        final MagicModelRecord record = TelescopeStore.recentModels().first;
        expect(record.modelKey, 'abc-123');
      });

      test('modelKey is empty string when model id is null', () async {
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));

        final MagicModelRecord record = TelescopeStore.recentModels().first;
        expect(record.modelKey, '');
      });

      test('attributes captures the model attribute map', () async {
        watcher.install();
        final _FakeModel model = _FakeModel(
          id: 'x-1',
          attrs: <String, dynamic>{'status': 'up', 'interval': 60},
        );

        await EventDispatcher.instance.dispatch(ModelSaved(model));

        final MagicModelRecord record = TelescopeStore.recentModels().first;
        expect(record.attributes, containsPair('status', 'up'));
        expect(record.attributes, containsPair('interval', 60));
      });

      test('time is set to a recent timestamp', () async {
        final DateTime before =
            DateTime.now().subtract(const Duration(seconds: 1));
        watcher.install();

        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));

        final MagicModelRecord record = TelescopeStore.recentModels().first;
        expect(record.time.isAfter(before), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // (e) uninstall is a no-op; EventDispatcher has no per-listener removal.
    //     Asserting it does not throw is sufficient.
    // -------------------------------------------------------------------------

    group('uninstall()', () {
      test('does not throw', () {
        watcher.install();
        expect(() => watcher.uninstall(), returnsNormally);
      });

      test('store retains records after uninstall (no teardown side-effect)',
          () async {
        watcher.install();
        await EventDispatcher.instance.dispatch(ModelCreated(_FakeModel()));
        watcher.uninstall();

        expect(TelescopeStore.recentModels(), hasLength(1));
      });
    });
  });
}
