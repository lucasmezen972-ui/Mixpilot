#if os(macOS)
import Foundation

extension MixPilotCloudError {
    /// Compatibility overload for REST helpers that capture a response body for
    /// diagnostics. Public user-facing errors deliberately keep the body private.
    static func rejected(statusCode: Int, body _: String) -> Self {
        .rejected(statusCode: statusCode)
    }
}
#endif
