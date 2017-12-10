//
//  PPSession.swift
//  Alternate
//
//  Created by Foucauld Degeorges on 09/12/2017.
//  Copyright © 2017 Foucauld Degeorges. All rights reserved.
//

import Foundation

class PPSession {
    var remainingSeconds: Int
    var timer: Timer
    var timerUpdateCallback: (Int) -> Void
    var timerEndCallback: () -> Void
    var timerPaused: Bool = false
    
    init(
        _timerUpdateCallback: @escaping (Int) -> Void,
        _timerEndCallback: @escaping () -> Void
    ) {
        self.remainingSeconds = 0
        self.timer = Timer()
        self.timerUpdateCallback = _timerUpdateCallback
        self.timerEndCallback = _timerEndCallback
    }
    
    @objc func updateTimer() {
        if self.timerPaused {
            return
        }

        if self.remainingSeconds < 1 {
            self.timer.invalidate()
            self.timerEndCallback()
            //Send alert to indicate time's up.
        } else {
            self.remainingSeconds -= 1
            self.timerUpdateCallback(self.remainingSeconds)
        }
    }
    
    func pauseTimer() {
        self.timerPaused = true
    }
    
    func resumeTimer() {
        self.timerPaused = false
    }
    
    func startSession(duration: Int) {
        self.remainingSeconds = duration * 60
        self.timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: (#selector(self.updateTimer)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(self.timer, forMode: .commonModes)
    }
    
}
