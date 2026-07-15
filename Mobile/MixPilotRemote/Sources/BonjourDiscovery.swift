import Foundation

@MainActor
final class BonjourDiscovery: NSObject, ObservableObject {
    @Published private(set) var endpoints: [RemoteEndpoint] = []
    @Published private(set) var isSearching = false

    private let browser = NetServiceBrowser()
    private var services: [NetService] = []

    override init() {
        super.init()
        browser.delegate = self
    }

    func start() {
        guard !isSearching else { return }
        endpoints = []
        services = []
        isSearching = true
        browser.searchForServices(ofType: "_mixpilot._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        services.forEach { $0.stop() }
        services = []
        isSearching = false
    }

    private func upsert(_ endpoint: RemoteEndpoint) {
        if let index = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[index] = endpoint
        } else {
            endpoints.append(endpoint)
            endpoints.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in self.isSearching = true }
    }

    nonisolated func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        Task { @MainActor in self.isSearching = false }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        Task { @MainActor in self.isSearching = false }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        Task { @MainActor in
            service.delegate = self
            self.services.append(service)
            service.resolve(withTimeout: 5)
        }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        Task { @MainActor in
            self.services.removeAll { $0 === service }
            self.endpoints.removeAll { $0.name == service.name }
        }
    }
}

extension BonjourDiscovery: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        guard let rawHost = sender.hostName, sender.port > 0 else { return }
        let host = rawHost.hasSuffix(".") ? String(rawHost.dropLast()) : rawHost
        let endpoint = RemoteEndpoint(name: sender.name, host: host, port: sender.port)
        Task { @MainActor in self.upsert(endpoint) }
    }
}
