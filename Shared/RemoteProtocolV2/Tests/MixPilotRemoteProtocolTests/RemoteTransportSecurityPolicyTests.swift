import XCTest
@testable import MixPilotRemoteProtocol

final class RemoteTransportSecurityPolicyTests: XCTestCase {
    func testInsecureTransportRequiresExplicitDebugOverride() {
        XCTAssertFalse(
            MixPilotRemoteTransportSecurityPolicy
                .allowsInsecureDevelopmentTransport(environment: [:])
        )
        XCTAssertFalse(
            MixPilotRemoteTransportSecurityPolicy.allowsInsecureDevelopmentTransport(
                environment: [
                    MixPilotRemoteTransportSecurityPolicy.insecureDevelopmentOverrideKey: "0"
                ]
            )
        )
#if DEBUG
        XCTAssertTrue(
            MixPilotRemoteTransportSecurityPolicy.allowsInsecureDevelopmentTransport(
                environment: [
                    MixPilotRemoteTransportSecurityPolicy.insecureDevelopmentOverrideKey: "1"
                ]
            )
        )
#else
        XCTAssertFalse(
            MixPilotRemoteTransportSecurityPolicy.allowsInsecureDevelopmentTransport(
                environment: [
                    MixPilotRemoteTransportSecurityPolicy.insecureDevelopmentOverrideKey: "1"
                ]
            )
        )
#endif
    }
}
