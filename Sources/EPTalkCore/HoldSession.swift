import Foundation

/// Translates validated paddle reports into shortcut edges. A resumed input
/// must first report release unless the same link went quiet while at rest.
public struct HoldSession: Sendable {
    public enum Edge: Equatable, Sendable { case down, up }

    public private(set) var ready = false
    public private(set) var holding = false
    private var lastReport: TimeInterval?
    private var resumeFromIdle = false

    public var hasReport: Bool { lastReport != nil }

    public init() {}

    public mutating func observe(_ report: AudioSignalEvent, at time: TimeInterval) -> Edge? {
        let resume = resumeFromIdle
        resumeFromIdle = false
        lastReport = time
        if !ready {
            ready = resume || (!report.paddle && !report.orange)
        }
        guard ready, holding != report.paddle else { return nil }
        holding = report.paddle
        return holding ? .down : .up
    }

    public mutating func expire(at time: TimeInterval) -> Edge? {
        guard let lastReport, time - lastReport >= 3 else { return nil }
        return loseSignal()
    }

    public mutating func loseSignal() -> Edge? {
        let resume = resumeFromIdle || (ready && !holding)
        let edge = reset()
        resumeFromIdle = resume
        return edge
    }

    public mutating func reset() -> Edge? {
        let edge: Edge? = holding ? .up : nil
        ready = false
        holding = false
        lastReport = nil
        resumeFromIdle = false
        return edge
    }
}
