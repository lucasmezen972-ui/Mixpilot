#if os(macOS)
import Foundation

// SAFETY: UserDefaults serializes access to its shared preference store. This
// bridge exposes that thread-safe behavior to Swift 6 without adding mutable
// wrapper state or permitting unsynchronized access to another object.
extension UserDefaults: @retroactive @unchecked Sendable {}
#endif
