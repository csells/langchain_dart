import 'dart:convert';
import 'package:json_schema/json_schema.dart' as js;
import 'package:langchain_compat/langchain_compat.dart';
import 'package:test/test.dart';

void main() {
  test('google - returns simple JSON object debug', () async {
    final schema = js.JsonSchema.create({
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'age': {'type': 'integer'},
      },
      'required': ['name', 'age'],
    });

    final agent = Agent('google:gemini-2.0-flash');
    final result = await agent.run(
      'Generate a person with name "John" and age 30',
      outputSchema: schema,
    );

    print('Result output: "${result.output}"');
    print('Result output length: ${result.output.length}');
    print('Result output isEmpty: ${result.output.isEmpty}');
    
    if (result.output.isEmpty) {
      print('Output is empty!');
      print('Messages:');
      for (final msg in result.messages) {
        print('  Role: ${msg.role}');
        for (final part in msg.parts) {
          if (part is TextPart) {
            print('    TextPart: "${part.text}"');
          }
        }
      }
    } else {
      final json = jsonDecode(result.output) as Map<String, dynamic>;
      expect(json['name'], isA<String>());
      expect(json['age'], isA<int>());
    }
  });
}