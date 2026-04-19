import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';
import 'ollama_adapter.dart';
import 'openai_compatible_adapter.dart';

/// Factory for creating provider adapters
class ChatAdapterFactory {
  static ChatProviderAdapter createAdapter(Provider provider) {
    switch (provider.kind) {
      case ProviderKind.ollama:
        return OllamaAdapter();
      case ProviderKind.openaiCompatible:
        return OpenAiCompatibleAdapter();
    }
  }
}
