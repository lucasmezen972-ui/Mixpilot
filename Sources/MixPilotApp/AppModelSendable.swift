#if os(macOS)

// AppModel is globally isolated to MainActor. The unchecked conformance documents
// that references may cross callback boundaries only to be re-entered on MainActor.
extension AppModel: @unchecked Sendable {}

#endif
