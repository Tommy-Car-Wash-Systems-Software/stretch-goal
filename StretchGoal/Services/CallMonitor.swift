import CoreAudio
import Foundation

/// "In a call" means some process has an input device running. Teams, Zoom, FaceTime and
/// friends open the mic for the duration of a call and close it after.
enum CallMonitor {
    static func microphoneInUse() -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return false }

        for device in devices where hasInputStreams(device) {
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                            mScope: kAudioObjectPropertyScopeGlobal,
                                                            mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &runningSize, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }

    private static func hasInputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: kAudioObjectPropertyScopeInput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }
}
