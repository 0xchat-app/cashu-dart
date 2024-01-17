
enum ResponseCode {
  success(0),
  failed(1),
  notAllowedError(10000),
  transactionError(11000),
  tokenAlreadySpentError(11001),
  secretTooLongError(11003),
  noSecretInProofsError(11004),
  keysetError(12000),
  keysetNotFoundError(12001),
  lightningError(20000),
  invoiceNotPaidError(20001);

  final int value;

  const ResponseCode(this.value);

  static ResponseCode fromValue(int value) {
    return ResponseCode.values.where((e) => e.value == value).firstOrNull ?? ResponseCode.failed;
  }
}


class CashuResponse<T> {
  CashuResponse({
    this.code = ResponseCode.success,
    this.errorMsg = '',
    T? data,
  }) : _data = data;

  /// Response code indicating the status of the response.
  final ResponseCode code;

  /// Error message providing details in case of a failure response.
  final String errorMsg;

  /// Private data field that holds the actual data of the response.
  final T? _data;

  /// Indicates whether the response is a success.
  bool get isSuccess => code == ResponseCode.success;

  /// Data associated with the response.
  ///
  /// This property should only be accessed when `isSuccess` is true.
  /// Attempting to access `data` when `isSuccess` is false may cause a runtime error
  /// due to null data.
  T get data => _data!;

  factory CashuResponse.fromErrorMap(Map map) {
    return CashuResponse(
      code: ResponseCode.fromValue(map['code']),
      errorMsg: map['detail'] ?? ''
    );
  }
}

