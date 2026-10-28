import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where session tokens live on the device.
///
/// Refresh tokens are long-lived (30 days for a foreman, 7 for a worker), so
/// they go to the platform keystore rather than plain app preferences: the
/// Keychain on iOS/macOS, the Keystore on Android, the Credential Manager on
/// Windows, WebCrypto-encrypted storage on web.
abstract interface class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The data-protection keychain needs the Keychain Sharing
            // entitlement, which needs a provisioning profile -- with a free
            // developer account that pins the build to the Mac that made it.
            // This app shares nothing with other apps, so the legacy keychain
            // is enough. Only read on macOS.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// For tests, and anything else that must not touch the platform keystore.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
