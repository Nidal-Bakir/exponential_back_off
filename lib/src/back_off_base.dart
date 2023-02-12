import 'dart:async';

import 'package:async/async.dart' show CancelableOperation;

import 'either.dart';

abstract class BackOff {
  /// Maximum retry attempts, defaults to 10 attempts.
  final int? maxAttempts;

  /// Maximum elapsed time while retrying, defaults to null.
  final Duration? maxElapsedTime;

  /// Maximum delay between retries, defaults to 30 seconds.
  final Duration maxDelay;

  BackOff({
    this.maxDelay = const Duration(seconds: 30),
    this.maxAttempts = 10,
    this.maxElapsedTime,
  }) : assert(maxAttempts != null || maxElapsedTime != null,
            'Can not have both maxAttempts and maxElapsedTime null');

  final _stopwatch = Stopwatch();
  Duration get elapsedTime {
    return _stopwatch.elapsed;
  }

  Duration _currentDelay = Duration.zero;
  Duration get currentDelay =>
      Duration(microseconds: _currentDelay.inMicroseconds);

  int _attemptCounter = 0;
  int get attemptCounter => _attemptCounter;

  void _incrementAttemptCounter() {
    ++_attemptCounter;
  }

  bool _isProcessRunning = false;

  bool isProcessStopped() {
    return !_isProcessRunning;
  }

  bool isProcessRunning() {
    return _isProcessRunning;
  }

  bool _isForceStop = false;

  /// Stop the all the work
  ///
  /// Note: if the [proc] is running it will not stop it but will ignore its
  /// future and return [Left] object with [IgnoredProcess] value.
  ///
  /// @mustCallSuper
  Future<void> stop() async {
    _isForceStop = true;
    await _cancelableOperation?.cancel();
  }

  bool _shouldStop({Duration? nextDelay}) {
    var shouldStop = _isForceStop;

    if (_cancelableOperation != null) {
      shouldStop |= _cancelableOperation!.isCanceled;
    }

    if (maxAttempts != null) {
      shouldStop |= _attemptCounter >= maxAttempts!;
    }

    if (maxElapsedTime != null && nextDelay != null) {
      shouldStop |= elapsedTime + nextDelay >= maxElapsedTime!;
    }

    return shouldStop;
  }

  /// Call`stop()`and reset everything to zero.
  ///
  /// @mustCallSuper
  Future<void> reset() async {
    await stop();
    _attemptCounter = 0;
    _currentDelay = Duration.zero;
    _isForceStop = false;
    _isProcessRunning = false;
    _stopwatch.stop();
    _stopwatch.reset();
  }

  /// Calculates the next back off interval given an [attempt] and [elapsedTime].
  Duration computeDelay(int attempt, Duration elapsedTime);

  CancelableOperation? _cancelableOperation;

  /// Keep Calling [proc] as long as:
  /// * Calling [proc] throws exception.
  /// * [retryIf] returns `true` for the thrown exception. if provided.
  /// * [attemptCounter] not equals [maxAttempts] if provided.
  /// * [elapsedTime] not equals [maxElapsedTime] if provided.
  /// * the process not explicitly stopped using [stop] or [reset].
  ///
  /// At every retry the [onRetry] function will be called (if given).
  ///
  /// Returns Either:
  /// * [Left] -> [Exception]
  /// * [Right] -> [T]
  Future<Either<Exception, T>> start<T>(
    Future<T> Function() proc, {
    FutureOr<bool> Function(Exception error)? retryIf,
    FutureOr<void> Function(Exception error)? onRetry,
  }) async {
    assert(attemptCounter == 0, 'Did you forget to call reset() ?');

    Either<Exception, T> resultToReturn;
    _isProcessRunning = true;
    _stopwatch.start();

    while (true) {
      _incrementAttemptCounter();

      try {
        _cancelableOperation = CancelableOperation.fromFuture(proc());
        final result = await _cancelableOperation!
            .valueOrCancellation(const IgnoredProcess());

        if (_cancelableOperation!.isCanceled) {
          resultToReturn = Left(result);
        } else {
          resultToReturn = Right(result as T);
        }

        break;
      } on Exception catch (error) {
        await onRetry?.call(error);

        if (_shouldStop()) {
          resultToReturn = Left(error);
          break;
        }

        if ((await retryIf?.call(error)) == false) {
          resultToReturn = Left(error);
          break;
        }

        final delay = computeDelay(attemptCounter, elapsedTime);

        if (_shouldStop(nextDelay: delay)) {
          resultToReturn = Left(error);
          break;
        }

        _currentDelay = delay;

        _cancelableOperation =
            CancelableOperation.fromFuture(Future.delayed(delay));
        await _cancelableOperation!.valueOrCancellation();

        if (_shouldStop()) {
          resultToReturn = Left(error);
          break;
        }
      }
    }

    _isProcessRunning = false;
    _stopwatch.stop();

    return resultToReturn;
  }
}

class IgnoredProcess implements Exception {
  final String? message;

  const IgnoredProcess([this.message]);

  @override
  String toString() {
    if (message == null) return "IgnoredProcess";
    return "IgnoredProcess: $message";
  }
}
