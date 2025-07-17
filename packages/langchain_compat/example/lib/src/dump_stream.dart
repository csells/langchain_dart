import 'dart:io';

import 'package:langchain_compat/langchain_compat.dart';

Future<void> dumpStream(Stream<ChatResult> stream) async {
  await stream.forEach((r) => stdout.write(r.output));
  stdout.writeln();
}
