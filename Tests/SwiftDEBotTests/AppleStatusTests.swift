import Foundation
import Testing

@testable import SwiftDEBot

@Suite struct AppleStatusTests {
  @Test func decodesOngoingEventWithoutEndDate() throws {
    // Apple reports ongoing incidents with a null endDate.
    let json = """
      {"services": [{"serviceName": "iCloud Mail", "events": [{
        "message": "This service may be slow or unavailable.",
        "eventStatus": "ongoing", "statusType": "Issue",
        "usersAffected": "Some users are affected",
        "datePosted": "11/17/2026 11:37 PST", "startDate": "11/17/2026 08:45 PST",
        "endDate": null
      }]}]}
      """
    let response = try JSONDecoder().decode(StatusResponse.self, from: Data(json.utf8))
    #expect(!response.services[0].description.contains("nil"))
  }
}
