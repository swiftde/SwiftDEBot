import AsyncHTTPClient
import Foundation

extension HTTPClient {
    func get<Response>(_ url: String, response: Response.Type) async throws -> Response where Response: Decodable {
        let request = HTTPClientRequest(url: url)
        let response = try await self.execute(request, timeout: .seconds(30))
        if response.status == .ok {
            let body = try await response.body.collect(upTo: 50 * 1024 * 1024) // 50 MB
            return try JSONDecoder().decode(Response.self, from: body)
        } else {
            throw response.status.description
        }
    }
}
