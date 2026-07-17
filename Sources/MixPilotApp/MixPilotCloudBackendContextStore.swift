#if os(macOS)
import MixPilotSystem

actor MixPilotCloudBackendContextStore {
    private var context: MixPilotCloudBackendContext?

    func update(_ context: MixPilotCloudBackendContext?) {
        self.context = context
    }

    func current() -> MixPilotCloudBackendContext? {
        context
    }
}
#endif
