[![exponential_back_off](https://github.com/Nidal-Bakir/exponential_back_off/actions/workflows/exponential_back_off.yml/badge.svg)](https://github.com/Nidal-Bakir/exponential_back_off/actions/workflows/exponential_back_off.yml) [![codecov](https://codecov.io/gh/Nidal-Bakir/exponential_back_off/branch/main/graph/badge.svg?token=WMK1RZQ2JE)](https://codecov.io/gh/Nidal-Bakir/exponential_back_off) [![exponential_back_off on pub.dev](https://img.shields.io/pub/v/exponential_back_off.svg)](https://pub.dev/packages/exponential_back_off)

## Retry failing processes like HTTP requests using an exponential interval between each retry

**Exponential backoff algorithm:**

- An exponential backoff algorithm retries requests exponentially,
 increasing the waiting time between retries up to a maximum backoff time.

<img width="512" src="https://raw.githubusercontent.com/Nidal-Bakir/exponential_back_off/main/digram_image.png"/>

## Features

- [X] Start process
- [X] Stop process
- [X] Reset Process
- [X] Set max attempts
- [X] Set max elapsed time
- [X] Set max delay between retries
- [X] Conditional retry
- [X] On retry callback
- [X] Tweak the exponential delay parameters
- [X] Specify the amount of randomness for the delays
- [X] Custom delay algorithm (inherit from the base class `BackOff`)

## Getting started

 1. Add the package to your `pubspec.yaml`

   ```YAML
   dependencies:
    exponential_back_off: ^x.y.z
   ```

2. Import `exponential_back_off` in a dart file.

```dart
import 'package:exponential_back_off/exponential_back_off.dart';
```

## Usage

- Create `ExponentialBackOff` object

```dart

final exponentialBackOff = ExponentialBackOff();
```

- Make a request

```dart
  final result = await exponentialBackOff.start<Response>(
    () => http.get(Uri.parse('https://www.gnu.org/')),
  );
```

- Handle the result\
    You can handel the result in two ways:
  - By checking if the result `isLeft` or `isRight`. and get the value accordingly.
  - Using the fold function `result.fold((error){},(data){})`. The fold function
     will call the first(Left) function if the result is error otherwise will call second
     function(Right) if the result is data.

   *The error will always be in **Left** and the data will always be in **Right***

  1. **Using if check:**

   ```dart
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
  ```

  2. **Using fold:**

   ```dart
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
    ```

#### NOTE

With the default configuration it will be retried up-to 10 times,
sleeping 1st, 2nd, 3rd, ..., 9th attempt: (will not sleep the 10th)

      randomPercent: >=0.0% <=15%
      
      1.  400 ms     +/- (randomPercent of 400 ms)
      2.  800 ms     +/- (randomPercent of 800 ms)
      3.  1600 ms    +/- (randomPercent of 1600 ms)
      4.  3200 ms    +/- (randomPercent of 3200 ms)
      5.  6400 ms    +/- (randomPercent of 6400 ms)
      6.  12800 ms   +/- (randomPercent of 12800 ms)
      7.  25600 ms   +/- (randomPercent of 25600 ms)
      8.  51200 ms   +/- (randomPercent of 51200 ms)
      9.  102400 ms  +/- (randomPercent of 102400 ms)
      10. 204800 ms  +/- (randomPercent of 204800 ms) **will not sleep it**

## Examples

**Because we love to see examples in the README (:**

- Simple use case with the default configuration:

```dart
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
```

- Reusing the same object with the default configuration:
  
```dart
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
```

- Tweaks the exponential delay parameters:

```dart
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

```

- Custom Delay
  - create a subclass from Backoff base class

      ```dart
      /// linier delays:
      ///
      ///  1. 1000 ms
      ///  2. 2000 ms
      ///  3. 3000 ms
      ///  4. 4000 ms
      ///  5. 5000 ms
      class CustomDelay extends BackOff {
        CustomDelay({
          super.maxAttempts,
          super.maxDelay,
          super.maxElapsedTime,
        }) : assert(maxAttempts != null || maxElapsedTime != null,
                  'Can not have both maxAttempts and maxElapsedTime null');

        @override
        Duration computeDelay(int attempt, Duration elapsedTime) {
          return Duration(seconds: attempt);
        }
      }
      
      ```

  - Use it as you normally do

      ```dart
        // Will be retried up-to 5 times,
        // sleeping 1st, 2nd, 3rd, ..., 4th attempt: (will not sleep the 5th)
        //
        //  1. 1000 ms
        //  2. 2000 ms
        //  3. 3000 ms
        //  4. 4000 ms
        //  5. 5000 ms   **will not sleep it**

        final customDelay = CustomDelay(maxAttempts: 5);

        print('max attempts: ' + customDelay.maxAttempts.toString());
        print('max delay: ' + customDelay.maxDelay.toString());
        print('max elapsed time: ' + customDelay.maxElapsedTime.toString());
        print('==================================================================');

        await customDelay.start(
          () => get(Uri.parse('https://www.gnu.org/')).timeout(
            Duration.zero, // it will always throw TimeoutException
          ),
          retryIf: (e) => e is SocketException || e is TimeoutException,
          onRetry: (error) {
            print('attempt: ' + customDelay.attemptCounter.toString());
            print('error: ' + error.toString());
            print('current delay: ' + customDelay.currentDelay.toString());
            print('elapsed time: ' + customDelay.elapsedTime.toString());
            print('--------------------------------------------------------');
          },
        );
      ```
