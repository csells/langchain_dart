import '../openai_chat/openai_chat_model.dart';

/// Cohere OpenAI-compatible model.
typedef CohereChatModel = OpenAIChatModel;

/// Cohere-specific constants
extension CohereChatModelConstants on CohereChatModel {
  /// The default model name for Cohere.
  static const String defaultName = 'command-r-plus';
  
  /// The default base URL for Cohere's OpenAI-compatible API.
  static final Uri defaultBaseUrl = Uri.parse('https://api.cohere.com/compatibility/v1');
  
  /// The environment variable name for the Cohere API key.
  static const String apiKeyName = 'COHERE_API_KEY';
}
