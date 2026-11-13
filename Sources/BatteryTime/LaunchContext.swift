import AppKit
import CoreServices

enum LaunchContext {
    static func shouldOpenSettings(for event: NSAppleEventDescriptor?) -> Bool {
        guard let event, event.eventID == kAEOpenApplication else { return true }
        let source = event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        return source != keyAELaunchedAsLogInItem && source != keyAELaunchedAsServiceItem
    }
}
