import 'dart:convert';
import 'dart:io';

Future<void> sed(File file, RegExp regex, String replacement) async {
  if (await file.exists() == false) {
    return;
  }

  final contents = await file.readAsString();
  const ls = LineSplitter();
  final inputLines = ls.convert(contents);

  final output =
      inputLines.map((line) => line.replaceAll(regex, replacement)).join('\n');

  await file.writeAsString(output);

  return;
}
