import CoreLocation
import Foundation

struct Station: Identifiable, Hashable {
    let code: String
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { code }
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
