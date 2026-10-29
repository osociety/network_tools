import 'dart:async';
import 'dart:math';

import 'package:network_tools/src/concurrency.dart';
import 'package:test/test.dart';

void main() {
  group('mapConcurrently', () {
    test('never runs more than maxConcurrency tasks at once', () async {
      int active = 0;
      int peak = 0;
      final List<int> items = List<int>.generate(30, (int i) => i);

      final results = await mapConcurrently<int, int>(items, (int item) async {
        active++;
        peak = max(peak, active);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        return item * 2;
      }, maxConcurrency: 4).toList();

      expect(peak, lessThanOrEqualTo(4));
      expect(results, hasLength(items.length));
      expect(
        results.map((ConcurrentResult<int> result) => result.value).toSet(),
        items.map((int item) => item * 2).toSet(),
      );
    });

    test('keeps the original index when completing out of order', () async {
      final results = await mapConcurrently<int, int>(<int>[0, 1, 2], (
        int item,
      ) async {
        await Future<void>.delayed(Duration(milliseconds: 30 - item * 10));
        return item;
      }).toList();

      expect(
        results.map((ConcurrentResult<int> result) => result.index).toList(),
        <int>[2, 1, 0],
      );
      expect(
        results.map((ConcurrentResult<int> result) => result.value).toList(),
        <int>[2, 1, 0],
      );
    });

    test('reports progress for every completed task', () async {
      final List<int> progress = <int>[];
      final results = await mapConcurrently<int, int>(
        <int>[1, 2, 3],
        (int item) async => item,
        onCompleted: progress.add,
      ).toList();

      expect(results, hasLength(3));
      expect(progress, <int>[1, 2, 3]);
    });

    test('emits null results', () async {
      final results = await mapConcurrently<int, int>(<int>[
        1,
        2,
      ], (int item) async => item.isEven ? item : null).toList();

      expect(
        results.map((ConcurrentResult<int> result) => result.value).toList(),
        <int?>[null, 2],
      );
    });

    test('closes immediately for an empty input', () async {
      final results = await mapConcurrently<int, int>(
        <int>[],
        (int item) async => item,
      ).toList();

      expect(results, isEmpty);
    });

    test('propagates errors from tasks', () async {
      final future = mapConcurrently<int, int>(<int>[1, 2, 3], (
        int item,
      ) async {
        if (item == 2) {
          throw StateError('boom');
        }
        return item;
      }, maxConcurrency: 1).toList();

      await expectLater(future, throwsStateError);
    });

    test('stops starting new tasks after the listener cancels', () async {
      int started = 0;
      final Stream<ConcurrentResult<int>> stream = mapConcurrently<int, int>(
        List<int>.generate(50, (int i) => i),
        (int item) async {
          started++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return item;
        },
        maxConcurrency: 2,
      );

      final StreamSubscription<ConcurrentResult<int>> subscription = stream
          .listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 12));
      await subscription.cancel();
      final int startedAtCancel = started;
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(started, startedAtCancel);
    });

    test('reports completion progress and forwards task errors', () async {
      final List<int> completed = <int>[];
      final List<Object> errors = <Object>[];
      final List<ConcurrentResult<int>> values = <ConcurrentResult<int>>[];

      final Stream<ConcurrentResult<int>> stream = mapConcurrently<int, int>(
        <int>[1, 2],
        (int item) async {
          if (item == 1) {
            throw StateError('boom');
          }
          return item;
        },
        onCompleted: completed.add,
      );

      final Completer<void> done = Completer<void>();
      stream.listen(values.add, onError: errors.add, onDone: done.complete);
      await done.future;

      expect(errors.single, isA<StateError>());
      expect(values.single.value, 2);
      expect(completed, <int>[1, 2]);
    });
  });
}
