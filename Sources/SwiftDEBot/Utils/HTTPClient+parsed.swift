import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1

extension HTTPClient {
  func get<Response>(
    _ url: String,
    headers: [String: String]? = nil,
    response: Response.Type
  ) async throws -> Response where Response: Decodable {
    var request = HTTPClientRequest(url: url)
    if let headers {
      request.headers = .init(headers.map { ($0.key, $0.value) })
    }
    let response = try await self.execute(request, timeout: .seconds(60))
    if response.status == .ok {
      let body = try await response.body.collect(upTo: 50 * 1024 * 1024)  // 50 MB
      return try JSONDecoder().decode(Response.self, from: body)
    } else {
      throw await HTTPStatusError(loggingBodyOf: response, from: url)
    }
  }

  func post<Response>(
    _ url: String,
    headers: [String: String]? = nil,
    body: (any Encodable)?,
    response: Response.Type
  ) async throws -> Response where Response: Decodable {
    var request = HTTPClientRequest(url: url)
    request.method = .POST
    if let headers {
      request.headers = .init(headers.map { ($0.key, $0.value) })
    }
    request.headers.add(name: "Content-Type", value: "application/json")
    if let body {
      let data = try JSONEncoder().encode(body)
      var buffer = ByteBufferAllocator().buffer(capacity: data.count)
      buffer.writeBytes(data)
      request.body = .bytes(buffer)
    }
    let response = try await self.execute(request, timeout: .seconds(60))
    if response.status == .ok {
      let body = try await response.body.collect(upTo: 50 * 1024 * 1024)  // 50 MB
      return try JSONDecoder().decode(Response.self, from: body)
    } else {
      throw await HTTPStatusError(loggingBodyOf: response, from: url)
    }
  }
}

struct HTTPStatusError: Error, CustomStringConvertible {
  let status: HTTPResponseStatus

  var description: String { status.description }

  /// Logs the start of the body, where APIs explain their errors. It stays out of `description` because some
  /// commands post that to the channel.
  init(loggingBodyOf response: HTTPClientResponse, from url: String) async {
    status = response.status
    var body = ByteBuffer()
    do {
      for try await var chunk in response.body {
        body.writeBuffer(&chunk)
        if body.readableBytes >= 500 { break }
      }
    } catch {}
    let host = URL(string: url)?.host ?? "unknown host"
    log.warning("\(host) returned \(status): \(String(buffer: body).prefix(500))")
  }
}
