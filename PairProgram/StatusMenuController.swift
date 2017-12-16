//
//  StatusMenuController.swift
//  PairProgram
//
//  Created by Foucauld Degeorges on 09/12/2017.
//  Copyright © 2017 Foucauld Degeorges. All rights reserved.
//

import Cocoa
import AVFoundation
import HotKey

let DEFAULT_DURATION = 3
enum PPError: Error {
    case unexpectedTransition(expectedState: PPState, currentState: PPState)
}

enum PPState {
    case STATE_INIT, STATE_PREFS, STATE_CODING, STATE_WAITING, STATE_CODING_PAUSED, STATE_WAITING_PAUSED, STATE_FINISHED
}

@available(OSX 10.11, *)
class StatusMenuController: NSViewController, PreferencesWindowDelegate, NSUserNotificationCenterDelegate {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var quickStartMenuItem: NSMenuItem!
    @IBOutlet weak var statusMenuLine: NSMenuItem!
    @IBOutlet weak var customStartMenuItem: NSMenuItem!
    @IBOutlet weak var continueMenuItem: NSMenuItem!
    @IBOutlet weak var pauseMenuItem: NSMenuItem!
    @IBOutlet weak var resumeMenuItem: NSMenuItem!
    @IBOutlet weak var endMenuItem: NSMenuItem!

    var session: PPSession!
    var preferencesWindow: PreferencesWindow!
    var audio: AVAudioPlayer?
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var currentCycle: Int = 1
    var currentPlayer: Int = 0
    var totalCycles: Int?
    var duration: Int?
    var state: PPState = .STATE_INIT
    let baseIcon: NSImage = NSImage(named: NSImage.Name(rawValue: "statusIcon"))!
    let player1Icon: NSImage = NSImage(named: NSImage.Name(rawValue: "player1Icon"))!
    let player2Icon: NSImage = NSImage(named: NSImage.Name(rawValue: "player2Icon"))!

    private var goHotKey: HotKey? {
        didSet {
            guard let goHotKey = goHotKey else {
                return
            }
            goHotKey.keyDownHandler = { [weak self] in
                self!.goHotKeyHit()
            }
        }
    }

    private var pauseHotKey: HotKey? {
        didSet {
            guard let pauseHotKey = pauseHotKey else {
                return
            }
            pauseHotKey.keyDownHandler = { [weak self] in
                self!.pauseHotKeyHit()
            }
        }
    }

    private var endHotKey: HotKey? {
        didSet {
            guard let endHotKey = endHotKey else {
                return
            }
            endHotKey.keyDownHandler = { [weak self] in
                self!.endHotKeyHit()
            }
        }
    }

    override func awakeFromNib() {
        baseIcon.isTemplate = true
        player1Icon.isTemplate = true
        player2Icon.isTemplate = true
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
        self.transitionToInit()

        goHotKey = HotKey(keyCombo: KeyCombo(key: .g, modifiers: [.option]))
        pauseHotKey = HotKey(keyCombo: KeyCombo(key: .p, modifiers: [.option]))
        endHotKey = HotKey(keyCombo: KeyCombo(key: .e, modifiers: [.option]))
        
        NSUserNotificationCenter.default.delegate = self
    }

    // HELPERS

    func initializePreferences() {
        let defaults = UserDefaults.standard
        if (defaults.integer(forKey: "duration") == 0) {
            defaults.set(DEFAULT_DURATION, forKey: "duration")
        }
    }

    func assertState(expectedState: PPState) throws {
        if (expectedState != self.state) {
            throw PPError.unexpectedTransition(expectedState: expectedState, currentState: self.state)
        }
    }

    static func toMinutes(seconds: Int) -> String {
        let extraSeconds = seconds % 60
        let minutes = (seconds - extraSeconds) / 60

        return String(minutes) + ":" + String(format: "%02d", extraSeconds)
    }

    func hasMoreRounds() -> Bool {
        return (self.totalCycles! == 0) || (self.currentCycle < self.totalCycles!) || (self.currentPlayer == 0)
    }
    
    func getNextPlayer() -> Int {
        return (self.currentPlayer + 1) % 2;
    }


    func updateStatusLine() {
        self.statusMenu.item(at: 0)?.title = getCurrentRunInfo()
    }

    func updateStartText() {
        self.statusMenu.item(at: 2)!.title = getStartText()
    }

    func getCurrentRunInfo() -> String {
        if (self.state == .STATE_INIT) {
            return NSLocalizedString("status.notRunning", comment: "")
        }
        if (self.totalCycles! > 0) {
            return String(format: NSLocalizedString("status.formatWithTotalCycles", comment: ""), self.currentCycle, self.totalCycles!, self.currentPlayer + 1)
        }
        return String(format: NSLocalizedString("status.format", comment: ""), self.currentCycle, self.currentPlayer + 1)
    }

    func getStartText() -> String {
        if (self.totalCycles! > 0) {
            return String(format: NSLocalizedString("start.defaultWithTotalCycles", comment: ""), self.totalCycles!, self.duration!)
        }
        return String(format: NSLocalizedString("start.default", comment: ""), self.duration!)
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
    
    func showNotification() {
        let notification = NSUserNotification()
        if self.state == .STATE_WAITING {
            notification.title = NSLocalizedString("notif.switch", comment: "")
            notification.informativeText = String(format: NSLocalizedString("notif.switchToPlayer", comment: ""), self.getNextPlayer() + 1)
            notification.hasActionButton = true
            notification.actionButtonTitle = NSLocalizedString("notif.switchAction", comment: "")
        }
        else if self.state == .STATE_FINISHED {
            notification.title = NSLocalizedString("notif.itsOver", comment: "")
            notification.informativeText = NSLocalizedString("notif.finished", comment: "")
            notification.hasActionButton = true
            notification.actionButtonTitle = NSLocalizedString("notif.end", comment: "")
        }
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func hideNotification() {
        NSUserNotificationCenter.default.removeAllDeliveredNotifications()
    }

    // EVENT HANDLERS

    func onTimerUpdate(remainingTime: Int) -> () {
        statusItem.title = StatusMenuController.toMinutes(seconds: remainingTime)
    }

    func onRunEnd() -> () {
        if (self.hasMoreRounds()) {
            self.transitionFromCodingToWaiting()
        }
        else {
            self.transitionFromCodingToFinished()
        }
    }

    @IBAction func quitClicked(sender: NSMenuItem) {
        self.transitionFromAnyToQuit()
    }

    @IBAction func startClicked(sender: NSMenuItem) {
        self.transitionFromInitToCoding()
    }

    @IBAction func continueClicked(sender: NSMenuItem) {
        self.transitionFromWaitingToCoding()
    }

    @IBAction func pauseClicked(sender: NSMenuItem) {
        if (self.state == .STATE_CODING) {
            return self.transitionFromCodingToCodingPause()
        }
        if (self.state == .STATE_WAITING) {
            return self.transitionFromWaitingToWaitingPause()
        }
    }

    @IBAction func resumeClicked(sender: NSMenuItem) {
        if (self.state == .STATE_CODING_PAUSED) {
            return self.transitionFromCodingPauseToCoding()
        }
        if (self.state == .STATE_WAITING_PAUSED) {
            return self.transitionFromWaitingPauseToCoding()
        }
    }

    @IBAction func endClicked(sender: NSMenuItem) {
        switch(self.state) {
        case .STATE_INIT:
            return
        case .STATE_PREFS:
            return
        case .STATE_CODING:
            return self.transitionFromCodingToInit()
        case .STATE_WAITING:
            return self.transitionFromWaitingToInit()
        case .STATE_CODING_PAUSED:
            return self.transitionFromCodingPauseToInit()
        case .STATE_WAITING_PAUSED:
            return self.transitionFromWaitingPauseToInit()
        case .STATE_FINISHED:
            return self.transitionFromFinishedToInit()
        }
    }

    func goHotKeyHit() {
        switch(self.state) {
        case .STATE_INIT:
            return self.transitionFromInitToCoding()
        case .STATE_WAITING:
            return self.transitionFromWaitingToCoding()
        case .STATE_CODING_PAUSED:
            return self.transitionFromCodingPauseToCoding()
        case .STATE_WAITING_PAUSED:
            return self.transitionFromWaitingPauseToCoding()
        case .STATE_PREFS:
            return
        case .STATE_CODING:
            return
        case .STATE_FINISHED:
            return self.transitionFromFinishedToInit()
        }
    }

    func pauseHotKeyHit() {
        switch(self.state) {
        case .STATE_INIT:
            return
        case .STATE_PREFS:
            return
        case .STATE_CODING:
            return self.transitionFromCodingToCodingPause()
        case .STATE_WAITING:
            return self.transitionFromWaitingToWaitingPause()
        case .STATE_CODING_PAUSED:
            return self.transitionFromCodingPauseToCoding()
        case .STATE_WAITING_PAUSED:
            return self.transitionFromWaitingPauseToCoding()
        case .STATE_FINISHED:
            return
        }
    }

    func endHotKeyHit() {
        switch(self.state) {
        case .STATE_INIT:
            return
        case .STATE_PREFS:
            return
        case .STATE_CODING:
            return self.transitionFromCodingToInit()
        case .STATE_WAITING:
            return self.transitionFromWaitingToInit()
        case .STATE_CODING_PAUSED:
            return self.transitionFromCodingPauseToInit()
        case .STATE_WAITING_PAUSED:
            return self.transitionFromWaitingPauseToInit()
        case .STATE_FINISHED:
            self.transitionFromFinishedToInit()
        }
    }

    @IBAction func startCustomClicked(sender: NSMenuItem) {
        self.transitionFromInitToPrefs()
    }

    func preferencesDidUpdate() {
        self.transitionFromPrefsToCoding()
    }

    func preferencesDidClose() {
        self.transitionFromPrefsToInit()
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        switch (notification.activationType) {
        case .actionButtonClicked:
            if (self.state == .STATE_WAITING) {
                return self.transitionFromWaitingToCoding()
            }
            return self.transitionFromFinishedToInit()
        default:
            break;
        }
    }


    // STATE CHANGE FUNCTIONS
    func transitionToInit() {
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = true
        self.endMenuItem.isHidden = true
        self.statusItem.image = self.baseIcon
        self.state = .STATE_INIT
        self.updateStartText()
    }

    func transitionFromInitToCoding() {
        try! self.assertState(expectedState: .STATE_INIT)
        self.session.startSession(duration: self.duration!)
        self.state = .STATE_CODING
        self.updateStatusLine()
        self.quickStartMenuItem.isHidden = true
        self.customStartMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = false
        self.endMenuItem.isHidden = false
        self.statusItem.image = player1Icon
        self.statusItem.title = StatusMenuController.toMinutes(seconds: 60 * self.duration!)
    }

    func transitionFromInitToPrefs() {
        try! self.assertState(expectedState: .STATE_INIT)
        preferencesWindow.showWindow(nil)
        self.state = .STATE_PREFS
        self.customStartMenuItem.isHidden = true
        self.quickStartMenuItem.isHidden = true
    }

    func transitionFromPrefsToInit() {
        try! self.assertState(expectedState: .STATE_PREFS)
        self.state = .STATE_INIT
        self.customStartMenuItem.isHidden = false
        self.quickStartMenuItem.isHidden = false
    }

    func transitionFromPrefsToCoding() {
        try! self.assertState(expectedState: .STATE_PREFS)

        let defaults = UserDefaults.standard
        self.duration = defaults.integer(forKey: "duration")
        self.totalCycles = defaults.integer(forKey: "cycles")
        self.updateStartText()

        self.session.startSession(duration: self.duration!)
        self.state = .STATE_CODING
        self.pauseMenuItem.isHidden = false
        self.endMenuItem.isHidden = false
        self.statusItem.image = player1Icon
        self.updateStatusLine()
        self.statusItem.title = StatusMenuController.toMinutes(seconds: 60 * self.duration!)
    }

    func transitionFromCodingToWaiting() {
        try! self.assertState(expectedState: .STATE_CODING)

        self.state = .STATE_WAITING
        self.playAlarm()
        self.showNotification()

        statusItem.title = NSLocalizedString("menu.switch", comment: "") //"Switch!"
        self.continueMenuItem.isHidden = false
        self.continueMenuItem.title = String(format: NSLocalizedString("menu.continue", comment: ""), self.getNextPlayer() + 1)
    }
    
    func transitionFromCodingToFinished() {
        try! self.assertState(expectedState: .STATE_CODING)
        
        self.state = .STATE_FINISHED
        self.playAlarm()
        self.showNotification()

        statusItem.title = "End!"
        self.pauseMenuItem.isHidden = true
    }

    func transitionFromWaitingToInit() {
        try! self.assertState(expectedState: .STATE_WAITING)

        audio?.stop()
        self.hideNotification()
        statusItem.title = nil
        self.currentPlayer = 0
        self.currentCycle = 1
        self.state = .STATE_INIT
        self.updateStatusLine()
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.endMenuItem.isHidden = true
        self.quickStartMenuItem.isHidden = false
        self.customStartMenuItem.isHidden = false
        self.statusItem.image = self.baseIcon
    }

    func transitionFromWaitingToCoding() {
        try! self.assertState(expectedState: .STATE_WAITING)

        audio?.stop()
        self.hideNotification()
        self.session.startSession(duration: self.duration!)
        self.currentPlayer = (self.currentPlayer + 1) % 2
        if (self.currentPlayer == 0) {
            self.currentCycle = self.currentCycle + 1
        }

        self.updateStatusLine()
        self.continueMenuItem.isHidden = true
        self.statusItem.image = self.currentPlayer == 0 ? self.player1Icon : self.player2Icon
        self.statusItem.title = StatusMenuController.toMinutes(seconds: 60 * self.duration!)

        self.state = .STATE_CODING
    }

    func transitionFromCodingToCodingPause() {
        try! self.assertState(expectedState: .STATE_CODING)

        self.session.pauseTimer()
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = false

        self.state = .STATE_CODING_PAUSED
    }

    func transitionFromCodingPauseToCoding() {
        try! self.assertState(expectedState: .STATE_CODING_PAUSED)

        self.session.resumeTimer()
        self.pauseMenuItem.isHidden = false
        self.resumeMenuItem.isHidden = true

        self.state = .STATE_CODING
    }

    func transitionFromWaitingToWaitingPause() {
        try! self.assertState(expectedState: .STATE_WAITING)

        audio?.stop()
        self.hideNotification()
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.resumeMenuItem.isHidden = false

        self.state = .STATE_WAITING_PAUSED
    }

    func transitionFromWaitingPauseToCoding() {
        try! self.assertState(expectedState: .STATE_WAITING_PAUSED)

        self.resumeMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = false

        self.state = .STATE_WAITING
        self.transitionFromWaitingToCoding()
    }

    func transitionFromCodingPauseToInit() {
        try! self.assertState(expectedState: .STATE_CODING_PAUSED)
        self.transitionFromCodingPauseToCoding()
        self.transitionFromCodingToInit()
    }

    func transitionFromWaitingPauseToInit() {
        try! self.assertState(expectedState: .STATE_WAITING_PAUSED)
        self.transitionFromWaitingPauseToCoding()
        self.transitionFromCodingToInit()
    }

    func transitionFromCodingToInit() {
        try! self.assertState(expectedState: .STATE_CODING)

        self.session.endTimer()
        self.statusItem.image = self.baseIcon
        self.quickStartMenuItem.isHidden = false
        self.customStartMenuItem.isHidden = false
        self.pauseMenuItem.isHidden = true
        self.endMenuItem.isHidden = true
        self.currentPlayer = 0
        self.currentCycle = 1
        statusItem.title = nil
        self.state = .STATE_INIT
        self.updateStatusLine()
    }
    
    func transitionFromFinishedToInit() {
        try! self.assertState(expectedState: .STATE_FINISHED)
    
        audio?.stop()
        self.hideNotification()
        statusItem.title = nil
        self.currentPlayer = 0
        self.currentCycle = 1
        self.state = .STATE_INIT
        self.updateStatusLine()
        self.continueMenuItem.isHidden = true
        self.pauseMenuItem.isHidden = true
        self.endMenuItem.isHidden = true
        self.quickStartMenuItem.isHidden = false
        self.customStartMenuItem.isHidden = false
        self.statusItem.image = self.baseIcon
    }

    func transitionFromAnyToQuit() {
        NSApplication.shared.terminate(self)
    }
}
