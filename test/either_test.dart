import 'package:test/test.dart';
import 'package:exponential_back_off/src/either.dart';

void main() {
  test('test Left Either', () {
    // arrange
    final error = Exception('error');
    Either<Exception, int> leftEither = Left(error);

    // act
    final isLeft = leftEither.isLeft();
    final isRight = leftEither.isRight();

    final getLeftLeftEither = leftEither.getLeft;
    final getLeftRightEither = leftEither.getRight;

    final getLeftValue = leftEither.getLeftValue;
    final getRightValue = leftEither.getRightValue;

    final foldResult = leftEither.fold(
      (l) => l,
      (r) => 'NO OP',
    );

    // assert
    expect(isLeft, isTrue);
    expect(isRight, isFalse);

    expect(getLeftLeftEither(), equals(leftEither));
    expect(() => getLeftRightEither(), throwsA(isA<NotRightException>()));

    expect(getLeftValue(), equals(error));
    expect(() => getRightValue(), throwsA(isA<NotRightException>()));

    expect(foldResult, equals(error));
  });

  test('test Right Either', () {
    // arrange
    final data = 1;
    Either<Exception, int> rightEither = Right(data);

    // act
    final isLeft = rightEither.isLeft();
    final isRight = rightEither.isRight();

    final getLeftLeftEither = rightEither.getLeft;
    final getLeftRightEither = rightEither.getRight;

    final getLeftValue = rightEither.getLeftValue;
    final getRightValue = rightEither.getRightValue;

    final foldResult = rightEither.fold(
      (l) => 'NO OP',
      (r) => r,
    );

    // assert
    expect(isLeft, isFalse);
    expect(isRight, isTrue);

    expect(() => getLeftLeftEither(), throwsA(isA<NotLeftException>()));
    expect(getLeftRightEither(), equals(rightEither));

    expect(getRightValue(), equals(data));
    expect(() => getLeftValue(), throwsA(isA<NotLeftException>()));

    expect(foldResult, equals(data));
  });
}
