//
//  PreferencesWindow.swift
//  PairProgram
//
//  Created by Foucauld Degeorges on 09/12/2017.
//  Copyright © 2017 Foucauld Degeorges. All rights reserved.
//

import Cocoa

protocol PreferencesWindowDelegate {
    func preferencesDidUpdate()
    func preferencesDidClose()
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {
    @IBOutlet weak var durationSelector: NSPopUpButton!
    @IBOutlet weak var numberOfCycles: NSPopUpButton!
    var delegate: PreferencesWindowDelegate?
    
    static let durationOptions:Array<String> = [
        "1 Minute", "2 Minutes", "3 Minutes", "4 Minutes", "5 Minutes",
        "6 Minute", "7 Minutes", "8 Minutes", "9 Minutes", "10 Minutes",
    ]
    
    static let cycleOptions:Array<String> = [
        "Unlimited", "1 Cycle", "2 Cycles", "3 Cycles", "4 Cycles", "5 Cycles",
        "6 Cycles", "7 Cycles", "8 Cycles", "9 Cycles", "10 Cycles",
    ]
    
    override var windowNibName : NSNib.Name! {
        return NSNib.Name("PreferencesWindow")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        durationSelector.removeAllItems()
        durationSelector.addItems(withTitles: PreferencesWindow.durationOptions)
        numberOfCycles.removeAllItems()
        numberOfCycles.addItems(withTitles: PreferencesWindow.cycleOptions)
        self.window?.level = .floating
        
        let defaults = UserDefaults.standard
        let selectedDurationText = self.makeDurationTextTitle(duration: defaults.integer(forKey: "duration"))
        let selectedCyclesText = self.makeCycleTextTitle(cycles: defaults.integer(forKey: "cycles"))
        numberOfCycles.selectItem(withTitle: selectedCyclesText)
        durationSelector.selectItem(withTitle: selectedDurationText)
        
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func makeDurationTextTitle(duration: Int) -> String {
        return PreferencesWindow.durationOptions[duration - 1]
    }
    
    func makeCycleTextTitle(cycles: Int) -> String {
        return PreferencesWindow.cycleOptions[cycles]
    }
    
    func makeDurationValue(text: String) -> Int {
        return PreferencesWindow.durationOptions.index(of: text)! + 1
    }
    
    func makeCyclesValue(text: String) -> Int {
        return PreferencesWindow.cycleOptions.index(of: text)!
    }

    @IBAction func cancelClicked(_ sender: NSButtonCell) {
        delegate?.preferencesDidClose()
        self.close()
    }
    
    @IBAction func startClicked(_ sender: NSButton) {
        let defaults = UserDefaults.standard
        defaults.setValue(self.makeDurationValue(text: durationSelector.selectedItem!.title), forKey: "duration")
        defaults.setValue(self.makeCyclesValue(text: numberOfCycles.selectedItem!.title), forKey: "cycles")
        delegate?.preferencesDidUpdate()
        self.close()
    }
    
}
