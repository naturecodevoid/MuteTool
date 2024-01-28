//
//  MuteToolApp.swift
//  MuteTool
//
//  Created by naturecodevoid on 1/21/24.
//

import SwiftUI
import CoreAudio
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // If changing the shortcut, you must change both toggleMuteMenuBar and toggleMuteGlobal
    static let toggleMuteMenuBar = KeyboardShortcut("`", modifiers: [.command])
    static let toggleMuteGlobal = Self("toggleMute", default: .init(.backtick, modifiers: [.command]))
}

class DeviceManager {
    private var defaultInputDevicePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    private var mutePropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
    
    private var currentInputDevice = kAudioObjectUnknown
    
    private var muted = false
    // convoluted but it works... I couldn't get the UI to update with any combination of making DeviceManager an ObservableObject, adding a @Binding, @Published, ...
    // keeping UI and device state separate seems better anyways, no need to run setMuted in DispatchQueue.main
    private var updateStoredMuted: (Bool) -> ()
    
    init(updateStoredMuted: @escaping (Bool) -> ()) {
        self.updateStoredMuted = updateStoredMuted
        
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultInputDevicePropertyAddress, nil) { [self] _, _ in
            updateCurrentInputDevice()
        }
        updateCurrentInputDevice()
    }
    
    private func getAudioObject(objectID: AudioObjectID, address: UnsafePointer<AudioObjectPropertyAddress>, data: UnsafeMutableRawPointer) {
        guard AudioObjectHasProperty(objectID, address) else { return }
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, address, 0, nil, &dataSize) == noErr else { return }
        guard AudioObjectGetPropertyData(objectID, address, 0, nil, &dataSize, data) == noErr else { return }
    }
    
    private func setAudioObject(objectID: AudioObjectID, address: UnsafePointer<AudioObjectPropertyAddress>, data: UnsafeMutableRawPointer) {
        guard AudioObjectHasProperty(objectID, address) else { return }
        
        var settable: DarwinBoolean = false
        AudioObjectIsPropertySettable(objectID, address, &settable)
        guard settable == true else { return }
        
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(objectID, address, 0, nil, &dataSize) == noErr else { return }
        guard AudioObjectSetPropertyData(objectID, address, 0, nil, dataSize, data) == noErr else { return }
    }
    
    private func updateCurrentInputDevice() {
        if currentInputDevice != kAudioDeviceUnknown {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(currentInputDevice), &mutePropertyAddress, nil, onUpdateMuted(_:_:))
        }
        
        do {
            var device = kAudioDeviceUnknown
            getAudioObject(objectID: AudioObjectID(kAudioObjectSystemObject), address: &defaultInputDevicePropertyAddress, data: &device)
            currentInputDevice = device
        }
        
        if currentInputDevice != kAudioDeviceUnknown {
            AudioObjectAddPropertyListenerBlock(AudioObjectID(currentInputDevice), &mutePropertyAddress, nil, onUpdateMuted(_:_:))
            updateMuted()
        }
    }
    
    private func onUpdateMuted(_: UInt32, _: UnsafePointer<AudioObjectPropertyAddress>) {
        updateMuted()
    }
    
    func updateMuted() {
        var data: UInt32 = 0
        getAudioObject(objectID: currentInputDevice, address: &mutePropertyAddress, data: &data)
        muted = data == 1
        DispatchQueue.main.async { [self] in
            updateStoredMuted(muted)
        }
    }
    
    private func setMuted() {
        var data: UInt32 = muted ? 1 : 0
        setAudioObject(objectID: currentInputDevice, address: &mutePropertyAddress, data: &data)
    }
    
    func toggleMute() {
        muted.toggle()
        DispatchQueue.main.async { [self] in
            updateStoredMuted(muted)
        }
        setMuted()
    }
}

class AppState: ObservableObject {
    private let mutedSound = NSSound(named: "muted")!
    private let unmutedSound = NSSound(named: "unmuted")!
    
    @Published var locked = false
    @Published var muted = false
    private var deviceManager: DeviceManager?
    
    init() {
        deviceManager = DeviceManager(updateStoredMuted: updateStoredMuted(_:))
        
        KeyboardShortcuts.onKeyUp(for: .toggleMuteGlobal) { [self] in
            guard !locked else { return }
            toggleMute()
        }
    }
    
    func playSound() {
        if mutedSound.isPlaying {
            mutedSound.stop()
        }
        if unmutedSound.isPlaying {
            unmutedSound.stop()
        }
        
        // muted won't be changed to the real value when we play the sound
        if !muted {
            mutedSound.play()
        } else {
            unmutedSound.play()
        }
    }
    
    func toggleMute() {
        playSound()
        
        // Better a crash here than silent fail
        deviceManager!.toggleMute()
    }
    
    private func updateStoredMuted(_ newMuted: Bool) {
        if muted != newMuted {
            playSound()
        }
        muted = newMuted
    }
}

@main
struct MuteToolApp: App {
    @StateObject private var state = AppState()
    
    var body: some Scene {
        MenuBarExtra("MuteTool", systemImage: state.muted ? "mic.slash" : "mic") {
            Text("MuteTool | Currently \(state.muted ? "muted" : "unmuted")")
            
            Button("Toggle Mute") {
                guard !state.locked else { return }
                state.toggleMute()
            }.keyboardShortcut(KeyboardShortcuts.Name.toggleMuteMenuBar)
            
            Divider()
            
            Button("Quit") {
                guard !state.locked else { return }
                
                // We don't want to leave the user muted when they quit the app
                if state.muted {
                    state.locked = true // Don't allow the user to mute themselves again
                    state.toggleMute()
                    // Wait for unmuted sound to play
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NSApplication.shared.terminate(nil)
                    }
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }.keyboardShortcut("q")
        }
    }
}
