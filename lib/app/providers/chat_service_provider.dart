import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/chat_service.dart';
import 'repository_providers.dart';

final chatServiceProvider = FutureProvider<ChatService>((ref) async {
  final providerRepo = await ref.watch(providerRepositoryProvider.future);
  final conversationRepo =
      await ref.watch(conversationRepositoryProvider.future);
  final messageRepo = await ref.watch(messageRepositoryProvider.future);
  return ChatService(
    providerRepo: providerRepo,
    conversationRepo: conversationRepo,
    messageRepo: messageRepo,
  );
});
