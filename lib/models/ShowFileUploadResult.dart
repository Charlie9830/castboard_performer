import 'package:castboard_core/storage/ShowfIleValidationResult.dart';

class ShowfileUploadResult {
  final ShowfileValidationResult? validationResult;
  final bool generalResult;

  ShowfileUploadResult(
      {required this.validationResult, required this.generalResult});

  ShowfileUploadResult.good()
      : validationResult = ShowfileValidationResult.good(),
        generalResult = true;
}
