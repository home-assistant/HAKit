import Foundation
import Starscream

internal class HAStarscreamCertificatePinningImpl: CertificatePinning {
    let evaluateCertificate: HAConnectionInfo.EvaluateCertificate
    init(evaluateCertificate: @escaping HAConnectionInfo.EvaluateCertificate) {
        self.evaluateCertificate = evaluateCertificate
    }

    func evaluateTrust(trust: SecTrust, domain: String?, completion: (PinningState) -> Void) {
        evaluateCertificate(trust, {
            switch $0 {
            case .success:
                completion(.success)
            case let .failure(error):
                // although it looks like it would always succeed, a Swift Error may not be convertable here
                completion(.failed(error as? CFError? ?? CFErrorCreate(nil, "UnknownSSL" as CFErrorDomain, 1, nil)))
            }
        })
    }
}
