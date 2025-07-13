import 'dart:convert';
import 'package:json_schema/json_schema.dart' as js;
import 'package:langchain_compat/langchain_compat.dart';
import 'package:logging/logging.dart';

void main() async {
  // Enable logging to see what's happening
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
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
  
  print('\nTesting Google typed output...');
  final result = await agent.run(
    'Generate a person with name "John" and age 30',
    outputSchema: schema,
  );
  
  print('\nOutput: "${result.output}"');
  print('Output length: ${result.output.length}');
  print('Messages: ${result.messages.length}');
  
  for (var i = 0; i < result.messages.length; i++) {
    final msg = result.messages[i];
    print('\nMessage $i: role=${msg.role}, parts=${msg.parts.length}');
    for (var j = 0; j < msg.parts.length; j++) {
      final part = msg.parts[j];
      if (part is TextPart) {
        print('  Part $j: TextPart="${part.text}"');
      } else {
        print('  Part $j: ${part.runtimeType}');
      }
    }
  }
}