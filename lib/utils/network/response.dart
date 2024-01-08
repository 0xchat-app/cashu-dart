
enum ResponseCode {
  success,
  failed,
  quoteIssued,
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
}

