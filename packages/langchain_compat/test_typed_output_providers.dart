import 'package:langchain_compat/langchain_compat.dart';

void main() {
  // Get all providers that support typed output
  final typedOutputProviders = ChatProvider.allWith({ProviderCaps.typedOutput});
  
  print('Providers with typedOutput capability:');
  for (final provider in typedOutputProviders) {
    print('  ${provider.name}: ${provider.defaultModelName}');
  }
}