#if os(macOS)
import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import Network

public struct ConnectivityStatus: Hashable, Sendable {
    public var isAvailable: Bool
    public var isExpensive: Bool
    public var interfaceDescription: String

    public init(isAvailable: Bool, isExpensive: Bool, interfaceDescription: String) {
        self.isAvailable = isAvailable
        self.isExpensive = isExpensive
        self.interfaceDescription = interfaceDescription
    }
}

public final class ConnectivityMonitor: @unchecked Sendable {
    public typealias Handler = @Sendable (ConnectivityStatus) -> Void

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mixpilot.connectivity", qos: .utility)
    private let lock = NSLock()
    private var latestStatus = ConnectivityStatus(
        isAvailable: false,
        isExpensive: false,
        interfaceDescription: "Inconnue"
    )
    private var started = false

    public init() {}

    public func start(handler: @escaping Handler) {
        lock.lock()
        guard !started else {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            let interface: String
            if path.usesInterfaceType(.wifi) {
                interface = "Wi-Fi"
            } else if path.usesInterfaceType(.wiredEthernet) {
                interface = "Ethernet"
            } else if path.usesInterfaceType(.cellular) {
                interface = "Cellulaire"
            } else {
                interface = "Autre"
            }
            let status = ConnectivityStatus(
                isAvailable: path.status == .satisfied,
                isExpensive: path.isExpensive,
                interfaceDescription: interface
            )
            self?.lock.lock()
            self?.latestStatus = status
            self?.lock.unlock()
            handler(status)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        guard started else {
            lock.unlock()
            return
        }
        started = false
        lock.unlock()
        monitor.cancel()
    }

    public func currentStatus() -> ConnectivityStatus {
        lock.lock()
        defer { lock.unlock() }
        return latestStatus
    }
}

public struct PowerStatus: Hashable, Sendable {
    public var connectedToPower: Bool
    public var batteryLevel: Double?
    public var lowPowerModeEnabled: Bool

    public init(connectedToPower: Bool, batteryLevel: Double?, lowPowerModeEnabled: Bool) {
        self.connectedToPower = connectedToPower
        self.batteryLevel = batteryLevel
        self.lowPowerModeEnabled = lowPowerModeEnabled
    }
}

public struct PowerStatusProbe: Sendable {
    public init() {}

    public func read() -> PowerStatus {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let rawSources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return PowerStatus(
                connectedToPower: true,
                batteryLevel: nil,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        for source in rawSources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let state = description[kIOPSPowerSourceStateKey as String] as? String
            let current = description[kIOPSCurrentCapacityKey as String] as? Double
            let maximum = description[kIOPSMaxCapacityKey as String] as? Double
            let level: Double?
            if let current, let maximum, maximum > 0 {
                level = min(1, max(0, current / maximum))
            } else {
                level = nil
            }
            return PowerStatus(
                connectedToPower: state == kIOPSACPowerValue as String,
                batteryLevel: level,
                lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        }

        return PowerStatus(
            connectedToPower: true,
            batteryLevel: nil,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}

public enum SleepAssertionError: Error, LocalizedError {
    case creationFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .creationFailed(let code): "Impossible de bloquer la mise en veille (code \(code))."
        }
    }
}

public final class SleepAssertionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var assertionID = IOPMAssertionID(0)

    public init() {}

    public func acquire(reason: String = "MixPilot exécute un set DJ autonome") throws {
        lock.lock()
        defer { lock.unlock() }
        guard assertionID == 0 else { return }

        var createdID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &createdID
        )
        guard result == kIOReturnSuccess else {
            throw SleepAssertionError.creationFailed(result)
        }
        assertionID = createdID
    }

    public func release() {
        lock.lock()
        defer { lock.unlock() }
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    deinit {
        release()
    }
}
#endif
