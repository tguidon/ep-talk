import AVFoundation
import AudioToolbox
import CoreAudio
import EPTalkCore

enum AudioCaptureEvent: Sendable {
    case listening
    case level(Double)
    case report(AudioSignalEvent)
    case lost
    case failed(String, retry: Bool)
}

// The engine and its observer belong to engineQueue. The decoder and meter
// belong to decodeQueue. Only capture admission and stop state share a lock.
final class AudioCapture: @unchecked Sendable {
    private static let engineQueue = DispatchQueue(label: "ep-talk.audio.engine")
    private let decodeQueue = DispatchQueue(label: "ep-talk.audio.decode", qos: .userInitiated)
    private let lock = NSLock()
    private var stopped = false
    private var pending = 0
    private var discontinuity = false
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?
    private var detector = SymbolDetector()
    private var lastMeterTime = 0.0
    private var peak: Float = 0
    private let deliver: @MainActor @Sendable (AudioCaptureEvent) -> Void

    init(deliver: @escaping @MainActor @Sendable (AudioCaptureEvent) -> Void) {
        self.deliver = deliver
    }

    func start(device: AudioDeviceID) {
        Self.engineQueue.async { [self] in
            guard !lock.withLock({ stopped }) else { return }
            let audioEngine = AVAudioEngine()
            var id = device
            guard let unit = audioEngine.inputNode.audioUnit,
                  AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice,
                    kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr else {
                report(.failed("Couldn’t open this input. Reconnect the adapter.", retry: true))
                return
            }

            let format = audioEngine.inputNode.inputFormat(forBus: 0)
            guard format.sampleRate == SymbolSet.sampleRate, format.channelCount > 0,
                  format.commonFormat == .pcmFormatFloat32 else {
                report(.failed("Set this input to 48,000 Hz in Audio MIDI Setup.", retry: false))
                return
            }

            engine = audioEngine
            audioEngine.inputNode.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
                self?.enqueue(buffer)
            }
            do { try audioEngine.start() }
            catch {
                report(.failed("Audio input couldn’t start. \(error.localizedDescription)", retry: true))
                tearDown()
                return
            }
            report(.listening)
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: audioEngine, queue: nil
            ) { [weak self] _ in
                Self.engineQueue.async { [weak self] in
                    self?.checkConfiguration(device: device)
                }
            }
        }
    }

    func stop() {
        lock.withLock { stopped = true }
        Self.engineQueue.async { [self] in tearDown() }
    }

    private func enqueue(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let accepted = lock.withLock {
            guard !stopped else { return false }
            guard pending < 6 else {
                discontinuity = true
                return false
            }
            pending += 1
            return true
        }
        guard accepted else { return }
        let stride = buffer.stride
        let samples = (0..<Int(buffer.frameLength)).map { channel[$0 * stride] }
        decodeQueue.async { [self] in
            defer { lock.withLock { pending -= 1 } }
            decode(samples)
        }
    }

    private func decode(_ samples: [Float]) {
        let (active, gap) = lock.withLock {
            let gap = discontinuity
            discontinuity = false
            return (!stopped, gap)
        }
        guard active else { return }
        if gap {
            detector = SymbolDetector()
            report(.lost)
        }
        let wasLocked = detector.locked
        let events = detector.process(samples: samples)
        _ = detector.drainDiagnostics()
        if wasLocked && !detector.locked { report(.lost) }
        for event in events { report(.report(event)) }

        for sample in samples { peak = max(peak, abs(sample)) }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastMeterTime >= 0.08 {
            lastMeterTime = now
            report(.level(max(-60, 20 * log10(Double(max(peak, 0.001))))))
            peak = 0
        }
    }

    private func checkConfiguration(device: AudioDeviceID) {
        guard !lock.withLock({ stopped }), let engine else { return }
        let current = engine.inputNode.inputFormat(forBus: 0)
        var selected: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let readsDevice = engine.inputNode.audioUnit.map {
            AudioUnitGetProperty($0, kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global, 0, &selected, &size) == noErr
        } ?? false
        guard !engine.isRunning || current.sampleRate != SymbolSet.sampleRate
                || !readsDevice || selected != device else { return }
        report(.failed("Audio input changed. Reconnecting…", retry: true))
        tearDown()
    }

    private func report(_ event: AudioCaptureEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.lock.withLock({ self.stopped }) else { return }
            self.deliver(event)
        }
    }

    private func tearDown() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        guard let oldEngine = engine else { return }
        engine = nil
        oldEngine.inputNode.removeTap(onBus: 0)
        oldEngine.stop()
    }
}
