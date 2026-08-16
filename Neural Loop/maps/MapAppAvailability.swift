import Foundation
import UIKit

@MainActor
enum MapAppAvailability {
    static var isAppleMapsInstalled: Bool {
        canOpen(scheme: "maps")
    }

    static var isGoogleMapsInstalled: Bool {
        canOpen(scheme: "comgooglemaps")
    }

    static var isWazeInstalled: Bool {
        canOpen(scheme: "waze")
    }

    private static func canOpen(scheme: String) -> Bool {
        guard let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
