//
//  StatusMenuController.swift
//  Alternate
//
//  Created by Foucauld Degeorges on 09/12/2017.
//  Copyright © 2017 Foucauld Degeorges. All rights reserved.
//

import Cocoa
import AVFoundation

let DEFAULT_DURATION = 3

// State definition
let STATE_INIT = "init"
let STATE_PREFS = "prefs"
let STATE_CODING = "coding"
let STATE_WAITING = "waiting"
let STATE_CODING_PAUSED = "coding paused"
let STATE_WAITING_PAUSED = "waiting paused"

enum AlternateError: Error {
    case unexpectedTransition(expectedState: String, currentState: String)
}


@available(OSX 10.11, *)
class StatusMenuController: NSViewController, PreferencesWindowDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var quickStartMenuItem: NSMenuItem!
    @IBOutlet weak var statusMenuLine: NSMenuItem!
    @IBOutlet weak var customStartMenuItem: NSMenuItem!
    @IBOutlet weak var continueMenuItem: NSMenuItem!
    @IBOutlet weak var pauseMenuItem: NSMenuItem!
    @IBOutlet weak var resumeMenuItem: NSMenuItem!
    
    var session: PPSession!
    var preferencesWindow: PreferencesWindow!
    var audio: AVAudioPlayer?
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var currentCycle: Int = 1
    var currentPlayer: Int = 0
    var totalCycles: Int?
    var duration: Int?
    var state: String = STATE_INIT
    
    let keycode = UInt16(0x61)
    
    func handler(event: NSEvent!) {
        if event.keyCode == self.keycode  {
            print("PRESSED")
        }
    }
    
    
    override func awakeFromNib() {
        let icon = NSImage(named: NSImage.Name(rawValue: "statusIcon"))
        icon?.isTemplate = true // best for dark mode
        statusItem.image = icon
        statusItem.menu = statusMenu
        preferencesWindow = PreferencesWindow()
        preferencesWindow.delegate = self
        self.initializePreferences()
        
        let defaults = UserDefaults.standard
        self.duration = defaults.integer(forKey: "duration")
        self.totalCycles = defaults.integer(forKey: "cycles")
        
        self.session = PPSession(
            _timerUpdateCallback: { time in self.onTimerUpdate(remainingTime: time)} ,
            _timerEndCallback: { self.onRunEnd() }
        )
        
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = true
        
        self.updateStartText()

        // ... to set it up ...
        let options = NSDictionary(object: kCFBooleanTrue, forKey: kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString) as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if (trusted) {
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: self.handler)
        }
    
    }
    
    func assertState(expectedState: String) throws {
        if (expectedState != self.state) {
            throw AlternateError.unexpectedTransition(expectedState: expectedState, currentState: self.state)
        }
    }
    
    func onTimerUpdate(remainingTime: Int) -> () {
        statusItem.title = StatusMenuController.toMinutes(seconds: remainingTime)
    }
    
    func hasMoreRounds() -> Bool {
        return (self.totalCycles! == 0) || (self.currentCycle < self.totalCycles!) || (self.currentPlayer == 0)
    }
    
    func onRunEnd() -> () {
        self.transitionFromCodingToWaiting()

    }
    
    static func toMinutes(seconds: Int) -> String {
        let extraSeconds = seconds % 60
        let minutes = (seconds - extraSeconds) / 60

        return String(minutes) + ":" + String(format: "%02d", extraSeconds)
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        self.transitionFromAnyToQuit()
    }
    
    @IBAction func startClicked(sender: NSMenuItem) {
        self.transitionFromInitToCoding()
    }
    
    @IBAction func continueClicked(sender: NSMenuItem) {
        if (self.hasMoreRounds()) {
           self.transitionFromWaitingToCoding()
        }
        else {
            self.transitionFromWaitingToInit()
        }

    }

    @IBAction func pauseClicked(sender: NSMenuItem) {
        if (self.state == STATE_CODING) {
            return self.transitionFromCodingToCodingPause()
        }
        if (self.state == STATE_WAITING) {
            return self.transitionFromWaitingToWaitingPause()
        }
    }
    
    @IBAction func resumeClicked(sender: NSMenuItem) {
        if (self.state == STATE_CODING_PAUSED) {
            return self.transitionFromCodingPauseToCoding()
        }
        if (self.state == STATE_WAITING_PAUSED) {
            return self.transitionFromWaitingPauseToCoding()
        }
    }
    
    func updateStatusLine() {
        self.statusMenu.item(at: 0)?.title = getCurrentRunInfo()
    }
    
    func updateStartText() {
        self.statusMenu.item(at: 2)!.title = getStartText()
    }
    
    func getCurrentRunInfo() -> String {
        if (self.state == STATE_INIT) {
            return "Not Running"
        }
        let playerString = "player " +
            String(self.currentPlayer + 1)
        
        let cycleString = "Round " + String(self.currentCycle) + (self.totalCycles! > 0 ? "/" + String(self.totalCycles!) : "")
        
        return cycleString + ", " + playerString
    }
    
    func getStartText() -> String {
        return "Start " + (self.totalCycles! > 0 ? String(self.totalCycles!) + " " : "") + "rounds of " + String(self.duration!) + " minutes"
    }
    
    @IBAction func startCustomClicked(sender: NSMenuItem) {
        self.transitionFromInitToPrefs()
    }
    
    func playAlarm() -> Void {
        if let asset = NSDataAsset(name: NSDataAsset.Name(rawValue: "sound")) {
            do {
                audio = try AVAudioPlayer(data: asset.data, fileTypeHint: "AVFileTypeWAVE")
                audio?.numberOfLoops = -1
                guard let audio = audio else { return }
                audio.prepareToPlay()
                audio.play()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    func preferencesDidUpdate() {
        self.transitionFromPrefsToCoding()
    }
    
    func initializePreferences() {
        let defaults = UserDefaults.standard
        if (defaults.integer(forKey: "duration") == 0) {
            defaults.set(DEFAULT_DURATION, forKey: "duration")
        }
    }
    
    // STATE CHANGE FUNCTIONS

    func transitionFromInitToCoding() {
        try! self.assertState(expectedState: STATE_INIT)
        self.session.startSession(duration: self.duration!)
        self.state = STATE_CODING
        self.updateStatusLine()
        self.quickStartMenuItem.isHidden = true
        self.customStartMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = false
    }
    
    func transitionFromInitToPrefs() {
        try! self.assertState(expectedState: STATE_INIT)
        preferencesWindow.showWindow(nil)
        self.state = STATE_PREFS
        self.customStartMenuItem.isHidden = true
    }
    
    func transitionFromPrefsToCoding() {
        try! self.assertState(expectedState: STATE_PREFS)

        let defaults = UserDefaults.standard
        self.duration = defaults.integer(forKey: "duration")
        self.totalCycles = defaults.integer(forKey: "cycles")
        self.updateStartText()
        
        self.session.startSession(duration: self.duration!)
        self.state = STATE_CODING
        self.quickStartMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = false
        self.updateStatusLine()
    }
    
    func transitionFromCodingToWaiting() {
        try! self.assertState(expectedState: STATE_CODING)

        statusItem.title = "Switch!"
        self.playAlarm()
        self.state = STATE_WAITING
        self.continueMenuItem.isHidden = false
        
        if (self.hasMoreRounds()) {
            self.continueMenuItem.title = "Continue (Player " + String(((self.currentPlayer + 1) % 2) + 1) + ")"
        }
        else {
            self.continueMenuItem.title = "Finish"
        }
    }
    
    func transitionFromWaitingToInit() {
        try! self.assertState(expectedState: STATE_WAITING)
        
        audio?.stop()
        statusItem.title = nil
        self.currentPlayer = 0
        self.currentCycle = 1
        self.updateStatusLine()
        self.state = STATE_INIT
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.quickStartMenuItem.isHidden = false
        self.customStartMenuItem.isHidden = false
    }
    
    func transitionFromWaitingToCoding() {
        try! self.assertState(expectedState: STATE_WAITING)
        
        audio?.stop()
        self.session.startSession(duration: self.duration!)
        self.currentPlayer = (self.currentPlayer + 1) % 2
        if (self.currentPlayer == 0) {
            self.currentCycle = self.currentCycle + 1
        }
        
        self.updateStatusLine()
        self.continueMenuItem.isHidden = true

        self.state = STATE_CODING
    }
    
    func transitionFromCodingToCodingPause() {
        try! self.assertState(expectedState: STATE_CODING)
        
        self.session.pauseTimer()
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = false
        
        self.state = STATE_CODING_PAUSED
    }
    
    func transitionFromCodingPauseToCoding() {
        try! self.assertState(expectedState: STATE_CODING_PAUSED)
        
        self.session.resumeTimer()
        self.pauseMenuItem.isHidden = false
        self.resumeMenuItem.isHidden = true
        
        self.state = STATE_CODING
    }
    
    func transitionFromWaitingToWaitingPause() {
        try! self.assertState(expectedState: STATE_WAITING)
        
        audio?.stop()
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = false
        
        self.state = STATE_WAITING_PAUSED
    }
    
    func transitionFromWaitingPauseToCoding() {
        try! self.assertState(expectedState: STATE_WAITING_PAUSED)
        
        self.resumeMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = false
        
        self.state = STATE_WAITING
        if (self.hasMoreRounds()) {
            self.transitionFromWaitingToCoding()
        }
        else {
            self.transitionFromWaitingToInit()
        }
    }
    
    func transitionFromAnyToQuit() {
        NSApplication.shared.terminate(self)
    }
}
