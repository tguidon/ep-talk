import EPTalkCore
import Testing

struct HoldSessionTests {
    private let released = AudioSignalEvent(paddle: false, orange: false)
    private let squeezed = AudioSignalEvent(paddle: true, orange: false)

    @Test func holdsAcrossRepeatedReportsAndReleasesOnce() {
        var session = HoldSession()
        #expect(session.observe(released, at: 0) == nil)
        #expect(session.observe(squeezed, at: 1) == .down)
        for index in 2...45 {
            #expect(session.expire(at: Double(index)) == nil)
            #expect(session.observe(squeezed, at: Double(index)) == nil)
        }
        #expect(session.observe(released, at: 46) == .up)
        #expect(session.observe(released, at: 47) == nil)
    }

    @Test func unplugWhileHeldReleasesAndRequiresRest() {
        var session = HoldSession()
        _ = session.observe(released, at: 0)
        #expect(session.observe(squeezed, at: 1) == .down)
        #expect(session.expire(at: 4) == .up)
        #expect(!session.hasReport)
        #expect(session.observe(squeezed, at: 5) == nil)
        #expect(session.hasReport && !session.ready)
        #expect(session.observe(released, at: 6) == nil)
        #expect(session.observe(squeezed, at: 7) == .down)
    }

    @Test func knownMicCanWakeOnSqueezeAfterIdle() {
        var session = HoldSession()
        _ = session.observe(released, at: 0)
        #expect(session.expire(at: 3) == nil)
        #expect(session.loseSignal() == nil)
        #expect(session.observe(squeezed, at: 10) == .down)
        #expect(session.reset() == .up)
        #expect(session.observe(squeezed, at: 11) == nil)
    }

    @Test func orangeAloneDoesNotGenerateShortcutEvents() {
        var session = HoldSession()
        _ = session.observe(released, at: 0)
        #expect(session.observe(.init(paddle: false, orange: true), at: 1) == nil)
    }
}
