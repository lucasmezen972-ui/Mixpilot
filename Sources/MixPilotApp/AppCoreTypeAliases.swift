#if os(macOS)
import MixPilotCore

// Swift imports are file-scoped. Keep the backend descriptor available to
// lightweight SwiftUI tool views without making them import the entire Core
// module solely for a read-only type annotation.
typealias DJBackendDescriptor = MixPilotCore.DJBackendDescriptor
#endif
