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
        NSLocalizedString("durationChoices.one", comment: ""),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 2),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 3),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 4),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 5),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 6),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 7),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 8),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 9),
        String(format: NSLocalizedString("durationChoices.many", comment: ""), 10)
    ]
    
    static let cycleOptions:Array<String> = [
        NSLocalizedString("cycleChoices.unlimited", comment: ""),
        NSLocalizedString("cycleChoices.one", comment: ""),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 2),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 3),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 4),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 5),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 6),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 7),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 8),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 9),
        String(format: NSLocalizedString("cycleChoices.many", comment: ""), 10)
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
