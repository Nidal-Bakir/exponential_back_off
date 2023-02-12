import 'dart:async';
import 'dart:io';

import 'package:exponential_back_off/exponential_back_off.dart';
import 'package:http/http.dart';

void main(List<String> arguments) async {
  // With the default configuration it will be retried up-to 10 times,
  // sleeping 1st, 2nd, 3rd, ..., 9th attempt: (will not sleep the 10th)
  //
  //   randomPercent: >=0.0% <=15%
  //
  //  1. 400 ms     +/- (randomPercent of 400 ms)
  //  2. 800 ms     +/- (randomPercent of 800 ms)
  //  3. 1600 ms    +/- (randomPercent of 1600 ms)
  //  4. 3200 ms    +/- (randomPercent of 3200 ms)
  //  5. 6400 ms    +/- (randomPercent of 6400 ms)
  //  6. 12800 ms   +/- (randomPercent of 12800 ms)
  //  7. 25600 ms   +/- (randomPercent of 25600 ms)
  //  8. 51200 ms   +/- (randomPercent of 51200 ms)
  //  9. 102400 ms  +/- (randomPercent of 102400 ms)
  //  10. 204800 ms +/- (randomPercent of 204800 ms) **will not sleep it**

  final exponentialBackOff = ExponentialBackOff();

  /// The result will be of type [Either<Exception, Response>]
  final result = await exponentialBackOff.start<Response>(
    // Make a request
    () {
      return get(Uri.parse('https://www.gnu.org/'))
          .timeout(Duration(seconds: 10));
    },
    // Retry on SocketException or TimeoutException and other then that the process
    // will stop and return with the error
    retryIf: (e) => e is SocketException || e is TimeoutException,
  );

  /// You can handel the result in two ways
  /// * By checking if the result `isLeft` or `isRight`. and get the value accordingly.
  /// * Using the fold function `result.fold((error){},(data){})`. will call the
  ///   first(Left) function if the result is error otherwise will call second
  ///   function(Right) if the result is data.
  ///
  /// The error will always be in Left and the data will always be in Right

  // using if check
  if (result.isLeft()) {
    //Left(Exception): handel the error
    final error = result.getLeftValue();
    print(error);
  } else {
    //Right(Response): handel the result
    final response = result.getRightValue();
    print(response.body);
  }

  // using fold:
  result.fold(
    (error) {
      //Left(Exception): handel the error
      print(error);
    },
    (response) {
      //Right(Response): handel the result
      print(response.body);
    },
  );

  print('==================================================================');
  print('Reusing the same object with the default configuration');
  print('==================================================================');

  // reset will call stop() and reset everything to zero
  await exponentialBackOff.reset();

  print('interval: ' + exponentialBackOff.interval.toString());
  print('max randomization factor: ' +
      exponentialBackOff.maxRandomizationFactor.toString());
  print('max attempts: ' + exponentialBackOff.maxAttempts.toString());
  print('max delay: ' + exponentialBackOff.maxDelay.toString());
  print('max elapsed time: ' + exponentialBackOff.maxElapsedTime.toString());
  print('==================================================================');

  await exponentialBackOff.start(
    () => get(Uri.parse('https://www.gnu.org/')).timeout(
      Duration.zero, // it will always throw TimeoutException
    ),
    retryIf: (e) => e is SocketException || e is TimeoutException,
    onRetry: (error) {
      print('attempt: ' + exponentialBackOff.attemptCounter.toString());
      print('error: ' + error.toString());
      print('current delay: ' + exponentialBackOff.currentDelay.toString());
      print('elapsed time: ' + exponentialBackOff.elapsedTime.toString());
      print('--------------------------------------------------------');
    },
  );
}
