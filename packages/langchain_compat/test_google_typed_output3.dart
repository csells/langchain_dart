import 'dart:convert';
import 'package:json_schema/json_schema.dart' as js;
import 'package:langchain_compat/langchain_compat.dart';

void main() async {
  final schema = js.JsonSchema.create({
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer'},
    },
    'required': ['name', 'age'],
  });

  final agent = Agent('google:gemini-2.0-flash');
  
  print('Testing Google typed output...');
  final result = await agent.run(
    'Generate a person with name "John" and age 30',
    outputSchema: schema,
  );
  
  print('Raw output: "${result.output}"');
  
  try {
    final json = jsonDecode(result.output) as Map<String, dynamic>;
    print('Decoded JSON: $json');
    print('name type: ${json['name'].runtimeType} value: ${json['name']}');
    print('age type: ${json['age'].runtimeType} value: ${json['age']}');
  } catch (e) {
    print('Error decoding JSON: $e');
  }
}