import 'dart:math';

import 'package:test/test.dart';

import 'package:exponential_back_off/exponential_back_off.dart';

class TestException implements Exception {
  final dynamic message;

  TestException([this.message]);

  @override
  String toString() {
    Object? message = this.message;
    if (message == null) return "TextException";
    return "TextException: $message";
  }
}

void main() {
  test('attemptCounter should equals maxAttempts', () async {
    // arrange
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );
    int callCounter = 0;

    // act
    await expo.start(() {
      ++callCounter;
      throw TestException('test throw');
    });

    // assert
    expect(expo.attemptCounter, equals(maxAttempts));
    expect(callCounter, equals(maxAttempts));
  });

  test('elapsedTime should be less then or equal to maxElapsedTime', () async {
    // arrange
    final maxElapsedTime = Duration(seconds: 3);
    final expo = ExponentialBackOff(
      maxElapsedTime: maxElapsedTime,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );

    // act
    await expo.start(() => throw TestException('test throw'));

    // assert
    expect(expo.elapsedTime, lessThanOrEqualTo(maxElapsedTime));
  });

  test(
      'elapsedTime should be equal to expected precise sleep time '
      'when maxRandomizationFactor equal 0 ', () async {
    // arrange
    final interval = Duration(milliseconds: 50);
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: interval,
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0,
    );

    int callCounter = 0;

    // act
    await expo.start(() {
      ++callCounter;
      throw TestException('test throw');
    });

    // assert
    final expectedPreciseSleepTimeMillis =
        (interval * pow(2, 1) + interval * pow(2, 2)).inMilliseconds;

    expect(
      expo.elapsedTime.inMilliseconds,
      inInclusiveRange(
        expectedPreciseSleepTimeMillis,
        expectedPreciseSleepTimeMillis +
            100, // + ~100 the natural processing time of the code
      ),
    );
    expect(callCounter, equals(maxAttempts));
    expect(expo.isProcessRunning(), isFalse);
  });

  test(
      'the computed delay should be equal to maxDelay in case the computed '
      'delay is grater than the specified maxDelay', () {
    // arrange
    final interval = Duration(seconds: 99);
    final maxDelay = Duration(seconds: 5);
    final expo = ExponentialBackOff(
      maxAttempts: 3,
      interval: interval,
      maxDelay: maxDelay,
      maxRandomizationFactor: 0.15,
    );

    // act
    final delay = expo.computeDelay(99, Duration.zero);

    // assert
    expect(delay, equals(maxDelay));
  });

  test(
      'computeDelay() should output delays in InclusiveRange[delay-rand,delay+rand] '
      'which follow the defined formula: delay = interval * 2^min(attempt,31) '
      '+/- (random percent`>= 0.0 and <=[randomizationFactor]`of that delay',
      () {
    final interval = const Duration(milliseconds: 200);
    final maxDelay = const Duration(seconds: 30);
    final maxRandFactor = 0.15;
    final expo = ExponentialBackOff(
      interval: interval,
      maxDelay: maxDelay,
      maxRandomizationFactor: maxRandFactor,
    );

    for (var i = 1; i <= 1000; i++) {
      // act
      final delay = expo.computeDelay(i, Duration.zero);

      // assert
      final exp = min(31, i);
      final expectedRawDelay = interval * pow(2, exp);
      var maxRandomDelay = expectedRawDelay + expectedRawDelay * maxRandFactor;
      var minRandomDelay = expectedRawDelay - expectedRawDelay * maxRandFactor;
      maxRandomDelay = maxRandomDelay > maxDelay ? maxDelay : maxRandomDelay;
      minRandomDelay = minRandomDelay > maxDelay ? maxDelay : minRandomDelay;

      expect(
        delay.inMilliseconds,
        inInclusiveRange(
          minRandomDelay.inMilliseconds,
          maxRandomDelay.inMilliseconds,
        ),
      );
    }
  });

  test(
      'calling stop() function should produce consistent result i.e: '
      'the value of CurrentDelay before calling stop() should be the same after '
      'calling stop() and the same applied for attemptCounter', () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 10,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );
    int callCounter = 0;

    // act
    expo.start(() {
      ++callCounter;
      throw TestException('test throw');
    });
    await Future.delayed(Duration(seconds: 2));

    final beforeStopCurrentDelay = expo.currentDelay;
    final beforeStopAttemptCounter = expo.attemptCounter;
    await expo.stop();
    final afterStopCurrentDelay = expo.currentDelay;
    final afterStopAttemptCounter = expo.attemptCounter;

    // assert
    expect(
      expo.isProcessStopped(),
      isTrue,
      reason: 'The process should be stopped',
    );

    expect(
      afterStopCurrentDelay,
      equals(beforeStopCurrentDelay),
      reason: 'CurrentDelay should be the same before and after the stop()',
    );
    expect(
      afterStopAttemptCounter,
      equals(beforeStopAttemptCounter),
      reason: 'AttemptCounter should be the same before and after the stop()',
    );

    expect(
      callCounter,
      equals(expo.attemptCounter),
    );
  });

  test(
      'calling reset() should call stop() function to stop the current process '
      'and then reset all the vars to its init value (zero)', () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 10,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );

    // act
    expo.start(() {
      throw TestException('test throw');
    });
    await Future.delayed(Duration(seconds: 2));

    await expo.reset();

    // assert
    expect(
      expo.isProcessStopped(),
      isTrue,
      reason: 'The process should be stopped',
    );

    expect(
      expo.elapsedTime,
      equals(Duration.zero),
      reason: 'The elapsedTime should be reset to Duration.zero',
    );
    expect(
      expo.attemptCounter,
      equals(0),
      reason: 'The attemptCounter should be reset to zero',
    );
  });

  test(
      'should return [Left] with [TextException] object as a value when calling '
      'start() and throwing [TextException] in its body', () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 3,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );

    final exception = TestException('test throw');

    // act
    final result = await expo.start(() {
      throw exception;
    });

    // assert
    expect(result, isA<Left>());
    expect(result.getLeftValue(), equals(exception));
    expect(expo.attemptCounter, equals(3));
  });

  test(
      'should return [Left] with [IgnoredProcess] object as a value when calling '
      'stop() while proc() function still working and not in back off delay',
      () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 3,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );

    // act
    final result = expo.start(() async {
      await Future.delayed(Duration(seconds: 1));
    });
    await Future.delayed(Duration(milliseconds: 200));
    await expo.stop();

    // assert
    final res = (await result);
    expect(res, isA<Left>());
    expect(res.getLeftValue(), isA<IgnoredProcess>());
    expect(expo.attemptCounter, equals(1));
  });

  test(
      'should return [Right] with [int] as a value when calling '
      'start() and returning [int] in its body', () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 10,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );

    final returnValue = 10;

    // act
    final result = await expo.start<int>(() async {
      await Future.delayed(Duration(milliseconds: 500));
      return returnValue;
    });

    // assert
    expect(result, isA<Right>());
    expect(result.getRightValue(), equals(returnValue));
    expect(expo.attemptCounter, equals(1));
  });

  test(
      'should return [Right] with [int] as a value when calling '
      'start() and returning [int] in its body with falling in the first time',
      () async {
    // arrange
    final expo = ExponentialBackOff(
      maxAttempts: 10,
      interval: const Duration(milliseconds: 200),
      maxDelay: const Duration(seconds: 30),
      maxRandomizationFactor: 0.15,
    );

    final returnValue = 10;
    int callCounter = 0;
    final exception = TestException('test throw');

    // act
    final result = await expo.start<int>(() async {
      ++callCounter;

      await Future.delayed(Duration(milliseconds: 300));

      if (callCounter == 2) {
        return returnValue;
      }

      throw exception;
    });

    // assert
    expect(result, isA<Right>());
    expect(result.getRightValue(), equals(returnValue));

    expect(expo.attemptCounter, equals(2));
    expect(callCounter, equals(2));
    expect(expo.isProcessStopped(), isTrue);
  });
  test('verify that onRetry() function get called on every attempt to retry',
      () async {
    // arrange
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );

    int callCounter = 0;
    int onRetryCallCounter = 0;

    // act
    await expo.start(
      () {
        ++callCounter;
        throw TestException('test throw');
      },
      onRetry: (error) {
        ++onRetryCallCounter;
      },
    );

    // assert
    expect(expo.attemptCounter, equals(maxAttempts));
    expect(callCounter, equals(expo.attemptCounter));
    expect(onRetryCallCounter, equals(expo.attemptCounter));
  });
  test(
      'verify that onRetry() and retryIf() functions not called when the process '
      'success from the first time', () async {
    // arrange
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );

    int callCounter = 0;
    int onRetryCallCounter = 0;
    int retryIfCallCounter = 0;
    int returnValue = 10;

    // act
    await expo.start(
      () async {
        ++callCounter;
        return returnValue;
      },
      retryIf: (error) {
        ++retryIfCallCounter;
        return true;
      },
      onRetry: (error) {
        ++onRetryCallCounter;
      },
    );

    // assert
    expect(expo.attemptCounter, equals(1));
    expect(callCounter, equals(expo.attemptCounter));
    expect(onRetryCallCounter, equals(0));
    expect(retryIfCallCounter, equals(0));
  });

  test(
      'verify that retryIf() break the loop and stop the process if it returned false',
      () async {
    // arrange
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );

    int callCounter = 0;
    int retryIfCallCounter = 0;

    final exception = TestException('test throw');
    // act
    final result = await expo.start(
      () async {
        ++callCounter;
        throw exception;
      },
      retryIf: (error) {
        ++retryIfCallCounter;
        return false;
      },
    );

    // assert
    expect(expo.attemptCounter, equals(1));
    expect(callCounter, equals(1));
    expect(retryIfCallCounter, equals(1));

    expect(result, isA<Left>());
    expect(result.getLeftValue(), isA<TestException>());
    expect(result.getLeftValue(), equals(exception));
  });

  test(
      'verify that retryIf() will not break the loop and the process will'
      'continue retrying if it returned true', () async {
    // arrange
    final maxAttempts = 3;
    final expo = ExponentialBackOff(
      maxAttempts: maxAttempts,
      interval: Duration(milliseconds: 200),
      maxDelay: Duration(seconds: 10),
      maxRandomizationFactor: 0.15,
    );

    int callCounter = 0;
    int retryIfCallCounter = 0;

    final exception = TestException('test throw');
    // act
    final result = await expo.start(
      () async {
        ++callCounter;
        throw exception;
      },
      retryIf: (error) {
        ++retryIfCallCounter;
        return true;
      },
    );

    // assert
    expect(expo.attemptCounter, equals(maxAttempts));
    expect(callCounter, equals(expo.attemptCounter));
    // -1 because retryIf() will not be called in the last retry
    expect(retryIfCallCounter, equals(maxAttempts - 1));

    expect(result, isA<Left>());
    expect(result.getLeftValue(), isA<TestException>());
    expect(result.getLeftValue(), equals(exception));
  });

  test(
    'calling reset() and using the object agin should have a consistent behavior, '
    'as it was called for the first time',
    () async {
      // arrange
      final maxAttempts = 3;
      final interval = Duration(milliseconds: 50);
      final maxRandFactor = 0.15;
      final expo = ExponentialBackOff(
        maxAttempts: maxAttempts,
        interval: interval,
        maxDelay: Duration(seconds: 10),
        maxRandomizationFactor: maxRandFactor,
      );

      int callCounter = 0;
      int retryIfCallCounter = 0;

      final exception = TestException('test throw');

      // act
      await expo.start(
        () async {
          ++callCounter;
          throw exception;
        },
        retryIf: (error) {
          ++retryIfCallCounter;
          return true;
        },
      );

      await expo.reset();
      callCounter = 0;
      retryIfCallCounter = 0;

      await expo.start(
        () async {
          ++callCounter;
          throw exception;
        },
        retryIf: (error) {
          ++retryIfCallCounter;
          return true;
        },
      );

      // assert

      expect(
        expo.isProcessRunning(),
        isFalse,
        reason: 'The process should be stopped',
      );

      var expectedRawDelay = interval * pow(2, 1);
      var maxRandomDelay = expectedRawDelay + expectedRawDelay * maxRandFactor;
      var minRandomDelay = expectedRawDelay - expectedRawDelay * maxRandFactor;
      expectedRawDelay = interval * pow(2, 2);
      maxRandomDelay += expectedRawDelay + expectedRawDelay * maxRandFactor;
      minRandomDelay += expectedRawDelay - expectedRawDelay * maxRandFactor;

      expect(
        expo.elapsedTime.inMilliseconds,
        inInclusiveRange(
          minRandomDelay.inMilliseconds,
          maxRandomDelay.inMilliseconds,
        ),
      );

      expect(
        expo.attemptCounter,
        equals(maxAttempts),
        reason: 'The attemptCounter should be 3',
      );

      expect(
        callCounter,
        equals(maxAttempts),
        reason: 'The callCounter should be 3',
      );
      expect(
        retryIfCallCounter,
        equals(maxAttempts - 1),
        reason: 'The retryIfCallCounter should be 3',
      );
    },
  );
}
