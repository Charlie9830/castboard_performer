import 'package:castboard_core/font-loading/FontLoadCandidate.dart';
import 'package:castboard_core/font-loading/FontLoading.dart';
import 'package:castboard_core/models/FontModel.dart';
import 'package:castboard_core/storage/Storage.dart';

/// Pulls Custom fonts from storage and loads into the Engine.
/// Returns a Set of ids representing any Fonts that could not be loaded.
/// This could be because the Engine rejected them, files were missing, FontModel.ref was invalid or bad.
Future<Set<String>> loadCustomFonts(List<FontModel> requiredFonts) async {
  if (requiredFonts.isEmpty) {
    return <String>{};
  }

  final List<FontModel> goodFonts = [];
  final List<FontModel> missingFonts = [];
  final existenceRequests = requiredFonts.map((font) =>
      _fontExistenceDelegate(font).then(
          (exists) => exists ? goodFonts.add(font) : missingFonts.add(font)));

  await Future.wait(existenceRequests);

  final List<FontLoadCandidate> candidates = [];
  final dataLoadRequests = goodFonts.map((font) => Storage.instance.getFontFile(font.ref)!
      .readAsBytes()
      .then((data) =>
          candidates.add(FontLoadCandidate(font.uid, font.familyName, data))));

  await Future.wait(dataLoadRequests);

  final loadingResults = await FontLoading.loadFonts(candidates);

  return [
    ...loadingResults
        .where((result) => result.loadResult!.success == false)
        .map((result) => result.uid),
    ...missingFonts.map((font) => font.uid)
  ].toSet();
}

///
/// Delegate for checking if a Font File exists. Will return false even if the file object itself is null, thus protecting
/// any .then() calls from a null exception.
///
Future<bool> _fontExistenceDelegate(FontModel font) async {
  final file = Storage.instance.getFontFile(font.ref);

  if (file == null) {
    return false;
  } else {
    return file.exists();
  }
}
