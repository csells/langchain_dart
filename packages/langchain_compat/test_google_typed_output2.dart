import 'dart:convert';
import 'package:json_schema/json_schema.dart' as js;
import 'package:langchain_compat/langchain_compat.dart';
import 'package:logging/logging.dart';

void main() async {
  // Enable logging to see what's happening
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    if (record.loggerName.contains('agent')) {
      print('[${record.level.name}] ${record.loggerName}: ${record.message}');
    }
  });

  final schema = js.JsonSchema.create({
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer'},
    },
    'required': ['name', 'age'],
  });

  final agent = Agent('google:gemini-2.0-flash');
  
  print('\nTesting Google typed output with streaming...');
  var chunks = <String>[];
  await for (final result in agent.runStream(
    'Generate a person with name "John" and age 30',
    outputSchema: schema,
  )) {
    if (result.output.isNotEmpty) {
      print('Got chunk: "${result.output}"');
      chunks.add(result.output);
    }
  }
  
  print('\nTotal chunks: ${chunks.length}');
  print('Combined output: "${chunks.join()}"');
}