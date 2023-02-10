import 'dart:math' as math;

import 'back_off_base.dart';

/// Implementation of [BackOff] that increases the back off period for each
/// retry attempt using a function [computeDelay] that grows exponentially with
/// added/subtracted random value.
///
/// With the default configuration it will be retried up-to 10 times,
/// sleeping 1st, 2nd, 3rd, ..., 9th attempt: (will not sleep the 10th)
///
///   randomPercent: >=0.0% <=15%
///
///  1. 400 ms     +/- (randomPercent of 400 ms)
///  2. 800 ms     +/- (randomPercent of 800 ms)
///  3. 1600 ms    +/- (randomPercent of 1600 ms)
///  4. 3200 ms    +/- (randomPercent of 3200 ms)
///  5. 6400 ms    +/- (randomPercent of 6400 ms)
///  6. 12800 ms   +/- (randomPercent of 12800 ms)
///  7. 25600 ms   +/- (randomPercent of 25600 ms)
///  8. 51200 ms   +/- (randomPercent of 51200 ms)
///  9. 102400 ms  +/- (randomPercent of 102400 ms)
///  10. 204800 ms +/- (randomPercent of 204800 ms) **will not sleep it**
///
/// **Example**
/// ```dart
///   final exponentialBackOff = ExponentialBackOff();
///   /// The result will be of type [Either<Exception, Response>]
///   final result = await exponentialBackOff.start<Response>(
///     // Make a request
///    () {
///     return get(Uri.parse('https://www.gnu.org/'))
///       .timeout(Duration(seconds: 10));
///    },
///    // Retry on SocketException or TimeoutException and other then that the process
///    // will stop and return with the error
///    retryIf: (e) => e is SocketException || e is TimeoutException,
///   );
///
///  result.fold(
///    (error) {
///      //Left(Exception): handel the error
///      print(error);
///    },
///   (response) {
///     //Right(Response): handel the result
///     print(response.body);
///    },
///  );
/// ```
class ExponentialBackOff extends BackOff {
  final _rand = math.Random();

  /// Delay interval that will growth exponentially.
  ///
  /// Defaults to 200 ms, which results in the following delays:
  ///
  ///  1. 400 ms
  ///  2. 800 ms
  ///  3. 1600 ms
  ///  4. 3200 ms
  ///  5. 6400 ms
  ///  6. 12800 ms
  ///  7. 25600 ms
  ///  8. 51200 ms
  ///  9. 102400 ms
  ///  10. 204800 ms
  ///
  /// Before applying [maxRandomizationFactor].
  final Duration interval;

  /// The maximum random percentage of the computed delay to be added/subtracted
  /// to/from the resulted delay, given as fraction between 0 and 1.
  ///
  /// e.g: If `0.15` (default) this will generate a
  /// value percentage between `0.0% and 0.15%` of that delay will be
  /// added/subtracted to/from the resulted delay.
  final double maxRandomizationFactor;

  /// Create exponential delay between retries.
  ///
  /// [maxAttempts]: Maximum retry attempts, defaults to 10 attempts.
  ///
  /// [maxElapsedTime]: Maximum elapsed time while retrying, defaults to null.
  ///
  /// [maxDelay]: Maximum delay between retries, defaults to 30 seconds.
  ExponentialBackOff({
    this.maxRandomizationFactor = 0.15,
    this.interval = const Duration(milliseconds: 200),
    super.maxAttempts = 10,
    super.maxElapsedTime,
    super.maxDelay = const Duration(seconds: 30),
  });

  /// Calculates the next back off interval using the formula:
  ///
  /// delay = interval * 2^min(attempt,31)
  /// +/- (random percent`>= 0.0 and <=[randomizationFactor]`of that delay.
  @override
  Duration computeDelay(int attempt, _) {
    final exp = math.min(attempt, 31); // prevent overflows.

    var delay = interval * math.pow(2, exp);

    // Random value in the range [-randomizationFactor, +randomizationFactor].
    final randomPercent = _rand.nextDouble() * maxRandomizationFactor * 2 -
        maxRandomizationFactor;

    final randomDelay = delay.inMilliseconds * randomPercent;

    delay = Duration(milliseconds: delay.inMilliseconds + randomDelay.ceil());

    return delay > maxDelay ? maxDelay : delay;
  }
}
