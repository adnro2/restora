class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

String errorMessage(Object error) => error is ApiException
    ? error.message
    : 'Something went wrong. Please try again.';

T parseModel<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException {
    throw const ApiException(
      'invalid_response',
      'The server returned an unexpected response. Try again.',
    );
  } on TypeError {
    throw const ApiException(
      'invalid_response',
      'The server returned an unexpected response. Try again.',
    );
  }
}
