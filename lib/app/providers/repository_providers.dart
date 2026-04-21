import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/dao/dao.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/outbox_service.dart';
import '../../platform/secure_storage/secure_storage.dart';
import 'chat_service_provider.dart';
import 'database_provider.dart';

/// Secure storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider DAO provider
final providerDaoProvider = FutureProvider<ProviderDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ProviderDao(db);
});

/// App setting DAO provider
final appSettingDaoProvider = FutureProvider<AppSettingDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AppSettingDao(db);
});

/// Conversation DAO provider
final conversationDaoProvider = FutureProvider<ConversationDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ConversationDao(db);
});

/// Message DAO provider
final messageDaoProvider = FutureProvider<MessageDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return MessageDao(db);
});

/// Provider model DAO provider
final providerModelDaoProvider = FutureProvider<ProviderModelDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ProviderModelDao(db);
});

/// Outbox job DAO provider
final outboxJobDaoProvider = FutureProvider<OutboxJobDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return OutboxJobDao(db);
});

/// Provider repository provider
final providerRepositoryProvider =
    FutureProvider<ProviderRepository>((ref) async {
  final dao = await ref.watch(providerDaoProvider.future);
  final secureStorage = ref.watch(secureStorageProvider);
  return ProviderRepository(dao, secureStorage);
});

/// Conversation repository provider
final conversationRepositoryProvider =
    FutureProvider<ConversationRepository>((ref) async {
  final dao = await ref.watch(conversationDaoProvider.future);
  return ConversationRepository(dao);
});

/// Message repository provider
final messageRepositoryProvider =
    FutureProvider<MessageRepository>((ref) async {
  final dao = await ref.watch(messageDaoProvider.future);
  return MessageRepository(dao);
});

/// Provider model repository provider
final providerModelRepositoryProvider =
    FutureProvider<ProviderModelRepository>((ref) async {
  final dao = await ref.watch(providerModelDaoProvider.future);
  return ProviderModelRepository(dao);
});

/// Outbox service provider
final outboxServiceProvider = FutureProvider<OutboxService>((ref) async {
  final outboxDao = await ref.watch(outboxJobDaoProvider.future);
  final chatService = await ref.watch(chatServiceProvider.future);
  return OutboxService(outboxDao, chatService);
});
