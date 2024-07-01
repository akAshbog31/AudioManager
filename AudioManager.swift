//
//  AudioManager.swift
//  SwiftBoilerPlate
//
//  Created by AKASH BOGHANI on 01/07/24.
//

import UIKit
import AVFoundation

// Protocol to notify about audio player events
protocol AudioPlayerDelegate: AnyObject {
    func audioPlayerDidFinishPlaying(_ player: AudioPlayer)
    func audioPlayerDidUpdateProgress(_ player: AudioPlayer, currentTime: TimeInterval, remainingTime: TimeInterval)
    func audioPlayerDidUpdateMetadata(_ player: AudioPlayer, metadata: [String: String])
}

class AudioPlayer: NSObject {
    // MARK: - Properties
    private var audioPlayer: AVAudioPlayer? // AVAudioPlayer instance
    private var timer: Timer? // Timer to track progress
    private let queue = DispatchQueue(label: "com.app.AudioPlayer") // Serial queue for thread safety
    
    var hasBeenPaused = false // Flag to track pause state
    weak var delegate: AudioPlayerDelegate? // Delegate to notify about player events

    // Computed property to check if audio is playing
    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    // Computed property to check if audio is loaded
    var isAudioLoaded: Bool {
        return audioPlayer != nil
    }

    // Property to get and set the audio player volume
    var volume: Float {
        get {
            return audioPlayer?.volume ?? 0.0
        }
        set {
            audioPlayer?.volume = newValue
        }
    }

    // Property to mute or unmute the audio
    var isMuted: Bool = false {
        didSet {
            audioPlayer?.volume = isMuted ? 0 : volume
        }
    }

    // MARK: - Functions
    // Function to load audio from a URL
    public func loadAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            extractMetadata(from: url)

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

        } catch {
            print("Error loading audio: \(error.localizedDescription)")
        }
    }

    // Function to play the audio
    public func playAudio() {
        guard let audioPlayer = audioPlayer else { return }
        
        queue.sync {
            audioPlayer.play()
            startTimer()
        }
    }

    // Function to pause the audio
    public func pauseAudio() {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
                hasBeenPaused = true
            } else {
                hasBeenPaused = false
            }
            stopTimer()
        }
    }

    // Function to replay the audio from the beginning
    public func replayAudio() {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            audioPlayer.stop()
            audioPlayer.currentTime = 0
            audioPlayer.play()
            startTimer()
        }
    }

    // Function to stop the audio
    public func stopAudio() {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            audioPlayer.stop()
            stopTimer()
        }
    }

    // Function to seek to a specific time in the audio
    public func seek(to time: TimeInterval) {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            audioPlayer.currentTime = time
            if audioPlayer.isPlaying {
                startTimer()
            }
        }
    }

    // Function to rewind the audio by a specified number of seconds
    public func backward(by seconds: TimeInterval) {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            let newTime = max(audioPlayer.currentTime - seconds, 0)
            audioPlayer.currentTime = newTime
            if audioPlayer.isPlaying {
                startTimer()
            }
        }
    }

    // Function to fast forward the audio by a specified number of seconds
    public func forward(by seconds: TimeInterval) {
        guard let audioPlayer = audioPlayer else { return }

        queue.sync {
            let newTime = min(audioPlayer.currentTime + seconds, audioPlayer.duration)
            audioPlayer.currentTime = newTime
            if audioPlayer.isPlaying {
                startTimer()
            }
        }
    }

    // Function to get the current time of the audio
    public func getCurrentTime() -> TimeInterval? {
        return queue.sync {
            return audioPlayer?.currentTime
        }
    }

    // Function to get the total duration of the audio
    public func getDuration() -> TimeInterval? {
        return queue.sync {
            return audioPlayer?.duration
        }
    }

    // Function to start the progress timer
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
    }

    // Function to stop the progress timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // Function called by the timer to update the progress
    @objc private func updateProgress() {
        guard let audioPlayer = audioPlayer else { return }
        let currentTime = audioPlayer.currentTime
        let remainingTime = audioPlayer.duration - currentTime

        if remainingTime <= 0 {
            delegate?.audioPlayerDidFinishPlaying(self)
            stopTimer()
        } else {
            delegate?.audioPlayerDidUpdateProgress(self, currentTime: currentTime, remainingTime: remainingTime)
        }
    }

    // Function to extract metadata from the audio file
    private func extractMetadata(from url: URL) {
        let asset = AVAsset(url: url)
        var metadata: [String: String] = [:]
        
        for item in asset.commonMetadata {
            if let key = item.commonKey?.rawValue, let value = item.stringValue {
                metadata[key] = value
            }
        }
        
        delegate?.audioPlayerDidUpdateMetadata(self, metadata: metadata)
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayer: AVAudioPlayerDelegate {
    // Delegate method called when audio playback finishes
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            delegate?.audioPlayerDidFinishPlaying(self)
            stopTimer()
        }
    }
}
