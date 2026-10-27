import Foundation
import IOKit.pwr_mgt

/// Assertions are owned by this process; macOS also releases them if it exits.
final class PowerManager {
    private var assertions: [IOPMAssertionID] = []
    var isEnabled: Bool { !assertions.isEmpty }

    func enable() throws {
        guard !isEnabled else { return }
        var created: [IOPMAssertionID] = []
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep,
                     kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var identifier: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Work Mode — user enabled keep awake" as CFString, &identifier
            )
            guard result == kIOReturnSuccess else {
                created.forEach { IOPMAssertionRelease($0) }
                throw PowerError(code: result)
            }
            created.append(identifier)
        }
        assertions = created
    }

    func disable() {
        assertions.forEach { IOPMAssertionRelease($0) }
        assertions.removeAll()
    }

    deinit { disable() }
}

struct PowerError: LocalizedError {
    let code: IOReturn
    var errorDescription: String? { "无法启用防休眠（系统错误 \(code)），请重试。" }
}
