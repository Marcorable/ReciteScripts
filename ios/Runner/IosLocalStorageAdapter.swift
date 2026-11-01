import Foundation

final class IosLocalStorageAdapter: LocalStorageHostApi {
  func excludeApplicationSupportFromBackup() throws {
    guard var directory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      throw localStorageError()
    }

    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
    } catch {
      throw localStorageError()
    }
  }

  private func localStorageError() -> LocalStoragePigeonError {
    LocalStoragePigeonError(
      code: "local_storage_preparation_failed",
      message: "로컬 저장소를 준비하지 못했습니다.",
      details: nil
    )
  }
}
