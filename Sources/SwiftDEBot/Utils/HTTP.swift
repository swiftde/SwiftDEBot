import Foundation
import Result

class HTTP: NSObject {
    lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)

    static var shared = HTTP()

    func get<Response>(
        url: URL,
        completion: @escaping (Result<Response, Error>) -> Void
    ) where Response: Decodable {
        let task = self.session.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data else {
                completion(.failure(error!))
                return
            }
            do {
                let response = try JSONDecoder().decode(Response.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

}

extension HTTP: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var credential: URLCredential? = nil
        if let serverTrust = challenge.protectionSpace.serverTrust {
            credential = URLCredential(trust: serverTrust)
        }
        completionHandler(.useCredential, credential)
    }
}
