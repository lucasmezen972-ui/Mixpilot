#if os(macOS)

// SAFETY: AppModel is globally isolated to MainActor. References may cross
// callback boundaries only so execution can immediately re-enter that actor;
// mutable model state is never accessed outside MainActor isolation.
extension AppModel: @unchecked Sendable {}

#endif
