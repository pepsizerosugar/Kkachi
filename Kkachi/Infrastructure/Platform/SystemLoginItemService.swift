import Foundation
import ServiceManagement

/// Implements login item registration using macOS 13+ Service Management APIs.
@MainActor
final class SystemLoginItemService: LoginItemServicing {
    init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
