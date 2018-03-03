//
//  ViewController.swift
//  testSounds
//
//  Created by Gregg Jaskiewicz on 03/03/2018.
//  Copyright © 2018 Gregg Jaskiewicz. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion

class ViewController: UIViewController {

    fileprivate var midiEngine: MidiEngine?
    fileprivate var x: Int = 21

    fileprivate let manager = CMMotionManager()

    fileprivate var accelerationHistory: [Double] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.midiEngine = try? MidiEngine()
        try? self.midiEngine?.setPatch(num: 0)

        if manager.isAccelerometerAvailable == true {
            manager.accelerometerUpdateInterval = 0.01
            manager.startAccelerometerUpdates(to: .main) { [weak self] (data: CMAccelerometerData?, error: Error?) in

                guard let strongSelf = self else {
                    return
                }

                if let acceleration = data?.acceleration {
                    let value = fabs(acceleration.x + acceleration.y + acceleration.z)
                    strongSelf.accelerationHistory.append(value)
                    if (strongSelf.accelerationHistory.count > 10) {
                        strongSelf.accelerationHistory.remove(at: 0)
                    }
                }
            }
        }
    }


    @IBAction func doStuff() {

        // find the last highest
        let highest = self.accelerationHistory.max() ?? 1.2

        print("highest value: \(highest)")

        var velocity = (highest-0.8)*64.0

        if velocity < 0 {
            velocity = 1
        }

        if velocity > 126 {
            velocity = 126
        }

        print("velocity: \(velocity)")


        self.midiEngine?.playNote(self.x, length: 0.15, velocity: UInt8(velocity))

        self.x += 1

        if self.x > 108 {
            self.x = 21
        }
    }

}


enum MidiEngineErrors: Error {
    case FailedToFindSoundBank
    case FailedToStartEngine
    case FailedToLoadSoundBank
}

final class MidiEngine {

    // MARK: Properties
    fileprivate let engine: AVAudioEngine
    fileprivate let soundbank: URL
    fileprivate let sampler: AVAudioUnitSampler

    fileprivate let melodicBank = UInt8(kAUSampler_DefaultMelodicBankMSB)

    init() throws {
        self.engine = AVAudioEngine()
        guard let soundbank = Bundle.main.url(forResource: "piano", withExtension: "sf2") else {
            throw MidiEngineErrors.FailedToFindSoundBank
        }

        self.soundbank = soundbank
        self.sampler = AVAudioUnitSampler()

        self.engine.attach(self.sampler)
        self.engine.connect(self.sampler, to: self.engine.mainMixerNode, format: nil)

        do {
            try self.engine.start()
        } catch let error {
            print(error.localizedDescription)
            throw MidiEngineErrors.FailedToStartEngine
        }
    }

    fileprivate func startNote(_ note: Int, velocity: UInt8) {
        self.sampler.startNote(UInt8(note), withVelocity: velocity, onChannel: 0)
    }

    fileprivate func stopNote(_ note: Int) {
        self.sampler.stopNote(UInt8(note), onChannel: 0)
    }

    func playNote(_ note: Int, length: TimeInterval, velocity: UInt8 = 64) {
        self.startNote(note, velocity: velocity)
        self.runCode(in:length) {
            self.stopNote(note)
        }
    }

    private func runCode(in timeInterval: TimeInterval, _ code:@escaping ()->(Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval, execute: code)
    }

    func setPatch(num: Int) throws {
        let newPatch = UInt8(num)
        let bank = self.melodicBank

        do {
            try self.sampler.loadSoundBankInstrument(at: self.soundbank,
                                                      program: newPatch,
                                                      bankMSB: bank,
                                                      bankLSB: 0)
        } catch let error {
            print(error.localizedDescription)
            throw MidiEngineErrors.FailedToLoadSoundBank
        }
    }

}

