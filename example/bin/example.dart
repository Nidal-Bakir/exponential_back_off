import 'dart:async';
import 'dart:io';

import 'package:exponential_back_off/exponential_back_off.dart';
import 'package:http/http.dart';

void main(List<String> arguments) async {
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
}
