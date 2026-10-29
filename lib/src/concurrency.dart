import 'dart:async';
import 'dart:math';

/// A result emitted by [mapConcurrently], tagged with the index of its input.
typedef ConcurrentResult<O> = ({int index, O? value});

/// Runs [task] for every item while keeping at most [maxConcurrency] tasks in
/// flight and emits each result as soon as it completes (completion order).
///
/// [onCompleted] is called once per finished task with the total number of
/// finished tasks, which makes it suitable for progress reporting.
Stream<ConcurrentResult<O>> mapConcurrently<I, O>(
  List<I> items,
  Future<O?> Function(I item) task, {
  int maxConcurrency = 128,
  void Function(int completed)? onCompleted,
}) {
  final StreamController<ConcurrentResult<O>> controller =
      StreamController<ConcurrentResult<O>>();
  if (items.isEmpty) {
    controller.close();
    return controller.stream;
  }

  final int limit = max(1, min(maxConcurrency, items.length));
  int nextIndex = 0;
  int active = 0;
  int completed = 0;
  bool cancelled = false;

  controller.onCancel = () {
    cancelled = true;
  };

  void pump() {
    if (cancelled) {
      return;
    }
    while (active < limit && nextIndex < items.length) {
      final int index = nextIndex++;
      active++;
      Future.sync(() => task(items[index])).then(
        (O? value) {
          active--;
          completed++;
          onCompleted?.call(completed);
          if (!cancelled && !controller.isClosed) {
            controller.add((index: index, value: value));
          }
          pump();
        },
        onError: (Object error, StackTrace stackTrace) {
          active--;
          completed++;
          onCompleted?.call(completed);
          if (!cancelled && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
          pump();
        },
      );
    }
    if (active == 0 && nextIndex >= items.length && !controller.isClosed) {
      controller.close();
    }
  }

  pump();
  return controller.stream;
}
