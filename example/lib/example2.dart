import 'dart:async';
import 'dart:io';

import 'package:exponential_back_off/exponential_back_off.dart';
import 'package:http/http.dart';

void main(List<String> arguments) async {
  // Will be retried up-to 5 times,
  // sleeping 1st, 2nd, 3rd, ..., 4th attempt: (will not sleep the 5th)
  //
  //   randomPercent: 0.0%
  //
  //  1. 200 ms    
  //  2. 400 ms     
  //  3. 800 ms    
  //  4. 1600 ms    
  //  5. 3200 ms   **will not sleep it**
 
  final exponentialBackOff = ExponentialBackOff(
    interval: Duration(milliseconds: 100),
    maxAttempts: 5,
    maxRandomizationFactor: 0.0,
    maxDelay: Duration(seconds: 15),
  );

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
