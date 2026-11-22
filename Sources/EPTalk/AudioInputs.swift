import Foundation
import CoreAudio

struct AudioInput: Identifiable, Equatable, Sendable {
    var id: AudioDeviceID
    var name: String
    var uid: String
    var isUSB: Bool
}

enum AudioInputs {
    static func list() -> [AudioInput] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.compactMap { id in
            var input = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &input, 0, nil, &inputSize) == noErr, inputSize > 0 else { return nil }
            var nameProperty = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameProperty, 0, nil, &nameSize, &name) == noErr,
                  let name else { return nil }
            let deviceName = name.takeRetainedValue() as String
            var uidProperty = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &uidProperty, 0, nil, &uidSize, &uid) == noErr, let uid else { return nil }
            var transportProperty = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var transport: UInt32 = 0, transportSize: UInt32 = 4
            _ = AudioObjectGetPropertyData(id, &transportProperty, 0, nil, &transportSize, &transport)
            return AudioInput(id: id, name: deviceName,
                uid: uid.takeRetainedValue() as String, isUSB: transport == kAudioDeviceTransportTypeUSB)
        }
    }
}
