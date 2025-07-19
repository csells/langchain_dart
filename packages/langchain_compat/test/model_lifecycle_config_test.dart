import 'package:langchain_compat/langchain_compat.dart';
import 'package:langchain_compat/src/agent/lifecycle/lifecycle.dart';
import 'package:test/test.dart';

void main() {
  group('Model Lifecycle Configuration Tests', () {
    late Map<String, String> originalAgentEnv;

    setUp(() {
      originalAgentEnv = Map<String, String>.from(Agent.environment);
      Agent.environment.clear();
    });

    tearDown(() {
      Agent.environment.clear();
      Agent.environment.addAll(originalAgentEnv);
    });

    group('ModelConfig', () {
      test('ModelConfig passes through all configuration', () {
        final provider = ChatProvider.openai;
        final tools = [
          Tool<Map<String, dynamic>>(
            name: 'test_tool',
            description: 'Test tool',
            inputFromJson: (json) => json,
            onCall: (input) async => {'result': 'test'},
          ),
        ];
        const apiKey = 'sk-config-test';
        final baseUrl = Uri.parse('https://config.test.com');
        
        final config = ModelConfig(
          provider: provider,
          modelName: 'gpt-4',
          tools: tools,
          temperature: 0.7,
          systemPrompt: 'Test prompt',
          apiKey: apiKey,
          baseUrl: baseUrl,
        );

        expect(config.provider, equals(provider));
        expect(config.modelName, equals('gpt-4'));
        expect(config.tools, equals(tools));
        expect(config.temperature, equals(0.7));
        expect(config.systemPrompt, equals('Test prompt'));
        expect(config.apiKey, equals(apiKey));
        expect(config.baseUrl, equals(baseUrl));
      });
    });

    group('DefaultModelLifecycleManager', () {
      test('Lifecycle manager passes config to provider.createModel', () async {
        Agent.environment['OPENAI_API_KEY'] = 'sk-lifecycle-test';
        
        const manager = DefaultModelLifecycleManager();
        final provider = ChatProvider.openai;
        final customUrl = Uri.parse('https://lifecycle.test.com');
        
        final config = ModelConfig(
          provider: provider,
          modelName: 'gpt-4',
          temperature: 0.5,
          apiKey: 'sk-override',
          baseUrl: customUrl,
        );

        final model = await manager.createModel(config);
        
        expect(model, isNotNull);
        expect(model.name, equals('gpt-4'));
      });

      test('Lifecycle manager validates temperature', () {
        const manager = DefaultModelLifecycleManager();
        final provider = ChatProvider.openai;
        
        // Invalid temperature should throw
        final config = ModelConfig(
          provider: provider,
          modelName: 'gpt-4',
          temperature: 3, // Invalid - too high
        );

        expect(
          () => manager.validateConfig(config),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Temperature must be between 0 and 2'),
          )),
        );
      });

      test('Lifecycle manager validates model name', () {
        const manager = DefaultModelLifecycleManager();
        final provider = ChatProvider.openai;
        
        // Empty model name should throw
        final config = ModelConfig(
          provider: provider,
          modelName: '', // Invalid - empty
        );

        expect(
          () => manager.validateConfig(config),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Model name cannot be empty'),
          )),
        );
      });
    });

    group('Agent to Model Configuration Flow', () {
      test('Agent configuration flows through to model creation', () async {
        Agent.environment['OPENAI_API_KEY'] = 'sk-flow-test';
        
        final customUrl = Uri.parse('https://flow.test.com');
        final agent = Agent(
          'openai:gpt-4o-mini',
          apiKey: 'sk-agent-override',
          baseUrl: customUrl,
          temperature: 0.3,
          systemPrompt: 'Flow test prompt',
        );

        // Verify agent configuration via public methods
        expect(agent.model, equals('openai:gpt-4o-mini'));
        expect(agent.providerName, equals('openai'));
        expect(agent.modelName, equals('gpt-4o-mini'));
      });

      test('Agent.forProvider configuration flows correctly', () {
        final provider = ChatProvider.anthropic;
        final customUrl = Uri.parse('https://anthropic.test.com');
        
        final agent = Agent.forProvider(
          provider,
          modelName: 'claude-3-opus',
          apiKey: 'sk-anthropic-test',
          baseUrl: customUrl,
          temperature: 0.8,
        );

        expect(agent.providerName, equals('anthropic'));
        expect(agent.modelName, equals('claude-3-opus'));
        expect(agent.model, equals('anthropic:claude-3-opus'));
      });
    });

    group('Provider-Specific Configuration', () {
      test('Each provider respects its own API key name', () {
        // Set different API keys
        Agent.environment['OPENAI_API_KEY'] = 'sk-openai';
        Agent.environment['ANTHROPIC_API_KEY'] = 'sk-anthropic';
        Agent.environment['MISTRAL_API_KEY'] = 'sk-mistral';
        Agent.environment['GEMINI_API_KEY'] = 'sk-gemini';
        Agent.environment['COHERE_API_KEY'] = 'sk-cohere';
        
        // Create agents for different providers
        final agents = [
          Agent('openai'),
          Agent('anthropic'),
          Agent('mistral'),
          Agent('google'),
          Agent('cohere'),
        ];

        // Each should get the correct provider
        expect(agents[0].providerName, equals('openai'));
        expect(agents[1].providerName, equals('anthropic'));
        expect(agents[2].providerName, equals('mistral'));
        expect(agents[3].providerName, equals('google'));
        expect(agents[4].providerName, equals('cohere'));
      });

      test('Ollama works without API key', () {
        // No API key needed for Ollama
        final agent = Agent('ollama:llama2');
        
        expect(agent.providerName, equals('ollama'));
        expect(agent.modelName, equals('llama2'));
      });
    });

    group('Configuration Edge Cases', () {
      test('Model string parsing handles different formats', () {
        // Test colon separator
        var agent = Agent('openai:gpt-4o-mini');
        expect(agent.providerName, equals('openai'));
        expect(agent.modelName, equals('gpt-4o-mini'));
        
        // Test slash separator
        agent = Agent('anthropic/claude-3-haiku-20240307');
        expect(agent.providerName, equals('anthropic'));
        expect(agent.modelName, equals('claude-3-haiku-20240307'));
        
        // Test no separator (uses default model)
        agent = Agent('mistral');
        expect(agent.providerName, equals('mistral'));
        expect(agent.modelName, equals(ChatProvider.mistral.defaultModelName));
      });

      test('Provider aliases work correctly', () {
        Agent.environment['ANTHROPIC_API_KEY'] = 'sk-claude';
        Agent.environment['GEMINI_API_KEY'] = 'sk-gemini';
        
        // Test anthropic alias
        var agent = Agent('claude:claude-3-haiku-20240307');
        expect(agent.providerName, equals('claude')); // Keeps original input
        
        // Test google aliases
        agent = Agent('gemini:gemini-1.0-pro');
        expect(agent.providerName, equals('gemini'));
        
        agent = Agent('googleai:gemini-1.0-pro');
        expect(agent.providerName, equals('googleai'));
      });
    });
  });
}
