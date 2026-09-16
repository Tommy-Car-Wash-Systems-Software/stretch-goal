import Testing
import Foundation
@testable import StretchGoalCore

@Suite struct CodecTests {
    @Test func daySummaryRoundTripsWithStableKeys() throws {
        let original = Fixtures.summary("2026-09-16", breaks: 4, water: 6, mindful: 1,
                                        updatedAt: Date(timeIntervalSince1970: 1_789_000_000))
        let data = try Codec.encode(original)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"date\" : \"2026-09-16\""))
        #expect(json.contains("\"schemaVersion\" : 1"))
        #expect(json.contains("\"waterMl\" : 1500"))
        #expect(json.contains("\"updatedAt\" : \"2026-09-1"))
        let decoded = try Codec.decode(DaySummary.self, from: data)
        #expect(decoded == original)
    }

    @Test func rejectsMalformedDate() {
        let bad = Data("""
        {"schemaVersion":1,"memberId":"x","deviceId":"y","date":"16/09/2026","timeZone":"UTC",
         "breaks":0,"waterTaps":0,"mindful":0,"activeSeconds":0,"longestSitSeconds":0,
         "updatedAt":"2026-09-16T15:42:10Z"}
        """.utf8)
        #expect(throws: DecodingError.self) { try Codec.decode(DaySummary.self, from: bad) }
    }

    @Test func profileRoundTrips() throws {
        let p = MemberProfile(memberId: "brianp", nickname: "Brian", joined: Date(timeIntervalSince1970: 1_700_000_000))
        let decoded = try Codec.decode(MemberProfile.self, from: Codec.encode(p))
        #expect(decoded == p)
    }
}
