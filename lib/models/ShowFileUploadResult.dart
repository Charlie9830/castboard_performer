import 'package:castboard_core/models/ManifestModel.dart';
import 'package:castboard_core/storage/ShowfileValidationResult.dart';

class ShowfileUploadResult {
  final ShowfileValidationResult? validationResult;
  final bool generalResult;

  ShowfileUploadResult({
    required this.validationResult,
    required this.generalResult,
  });

  ShowfileUploadResult.good(ManifestModel? manifest)
      : validationResult = ShowfileValidationResult.good(manifest),
        generalResult = true;
}
