#if os(macOS)
import Foundation

// UserDefaults is documented and implemented as a thread-safe shared preference
// store. The macOS SDK used by this project does not expose that guarantee as an
// available Sendable conformance, so bridge it explicitly for Swift 6 checking.
extension UserDefaults: @retroactive @unchecked Sendable {}
#endif
