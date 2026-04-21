import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db/dao/dao.dart';
import '../../data/repositories/repositories.dart';
import '../../platform/secure_storage/secure_storage.dart';
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
