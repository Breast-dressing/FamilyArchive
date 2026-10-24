import Foundation
import Observation

struct HARImportRequest: Identifiable, Equatable {
    let id = UUID()
    let familyURL: String
}

@Observable
final class FileImportCoordinator {
    var request: HARImportRequest?

    func requestHARImport(for familyURL: String) {
        request = HARImportRequest(familyURL: familyURL)
    }
}
