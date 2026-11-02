import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut:
        'lib/src/infrastructure/database/generated/local_storage_api.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Runner/Generated/LocalStorageApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'LocalStoragePigeonError'),
  ),
)
@HostApi()
abstract class LocalStorageHostApi {
  void excludeApplicationSupportFromBackup();
}
