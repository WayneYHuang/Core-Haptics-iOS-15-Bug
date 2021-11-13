//
//  ViewController.swift
//  Core Haptics iOS 15 Bug Demo
//
//  **** PURPOSE ****
//  Simple project demonstrating that on iOS 15, Core Haptics custom pattern seems to conflict with AVAudioSession configured with category of .playback and option of .duckOthers.
//
//  **** EXPECTED BEHAVIOR ****
//  When press play button in app, music will begin playing. Custom "heart beat" haptic pattern should also begin playing.
//
//  **** ACTUAL BEHAVIOR ****
//  Haptic pattern plays on iPhone running iOS 14, but not iOS 15.
//  Only way to resolve in iOS 15 seems to be to remove the .duckOthers AVAudioSession option.
//
//
//  ^^^^ TO REPLICATE PROBLEM: ^^^^
//  1. Build and run this project on an actual device that supports haptics (iPhone 8 or later) running iOS 14, not iOS 15
//  2. Press play button in app. Music will play, and custom "heart beat" haptic pattern will play.
//  3. Build and run this project, this time on another iPhone that is running iOS 15.0+.  Music will play, but custom haptic pattern will not play at all.
//  4. To get the haptic engine to work on iOS 15, one way seems to be to comment out line 83 below, and un-comment line 84 (i.e., remove .duckOthers option, and replace with .mixWithOthers). Re-run on iOS 15. Custom haptic pattern should now play.



import UIKit
import AVKit
import CoreHaptics

class ViewController: UIViewController {
    
    // MARK: - Class Properties
    var musicPlayer: AVAudioPlayer?
    var isPlaying = false
    
    private let playPauseButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "playButtonWhite"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(playPauseButtonPressed(_:)), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Core Haptics properties
    var supportsHaptics: Bool = {
        return AppDelegate.shared().supportsHaptics
    }()
    private var engine: CHHapticEngine? = nil
    var burstTimer: Timer?
    
    
    // MARK: - Controller Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .systemPurple
        
        setupViews()
        setupAudio()
        createAndStartHapticEngine()
    }
    
    
    // MARK: - Methods
    private func setupViews() {
        
        self.view.addSubview(playPauseButton)
        let largePlayPauseButtonSize: CGFloat = 120
        
        NSLayoutConstraint.activate([
            playPauseButton.widthAnchor.constraint(equalToConstant: largePlayPauseButtonSize),
            playPauseButton.heightAnchor.constraint(equalToConstant: largePlayPauseButtonSize),
            playPauseButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
            
        ])
    }
    
    private func setupAudio() {
        
        // Setup AVAudioSession
        do {
            
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers]) // <-- This conflicts with Core Haptics on iOS 15, but not iOS 14
            //try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])   // <-- To resolve on iOS 15, need to replace .duckOthers with .mixWithOthers
            try AVAudioSession.sharedInstance().setActive(true)
            
        } catch {
            print("Error activating AVAudioSession: \(error)")
        }
        
        
        // Create path to local audio file and prepare AVAudioPlayer to play the track
        self.musicPlayer = AVAudioPlayer()
        let audioPath = Bundle.main.path(forResource: "classical0.m4a", ofType:nil)!
        let audioURL = URL(fileURLWithPath: audioPath)
        
        do {
          
            musicPlayer = try AVAudioPlayer(contentsOf: audioURL)

            if let player = musicPlayer {
   
                player.prepareToPlay()
                player.numberOfLoops = -1  // set to loop infinitely

            } else {
                assertionFailure("Unable to instantiate audio player with URL passed to it")
            }

        } catch {
            print("Error instantiating AVAudioPlayers")
        }
        
    }
    
    private func playAudio() {
        print("Audio is about to play")
        guard let pauseButtonGradientImage = UIImage(named: "pauseButtonPurpleGradient.png") else { return }
        
        musicPlayer?.play()
      
        isPlaying = true
        playPauseButton.setImage(pauseButtonGradientImage, for: .normal) // provide user feedback by changing icon color
       
    }
    
    private func pauseAudio() {
        print("Audio is about to pause")
        guard let playButtonWhiteImage = UIImage(named: "playButtonWhite.png") else { return }
        
        musicPlayer?.pause()
        
        isPlaying = false
        playPauseButton.setImage(playButtonWhiteImage, for: .normal) // provide user feedback by changing icon color
    }
    
    private func createAndStartHapticEngine() {
        
        // Below code is from https://developer.apple.com/documentation/corehaptics/preparing_your_app_to_play_haptics
        
        // Create and configure a haptic engine.
        do {
            engine = try CHHapticEngine()
        } catch let error {
            fatalError("Engine Creation Error: \(error)")
        }
        
        
        // The stopped handler alerts you of engine stoppage.
        engine?.stoppedHandler = { reason in
            print("Stop Handler: The engine stopped for reason: \(reason.rawValue)")
            switch reason {
            case .audioSessionInterrupt:
                print("Audio session interrupt")
            case .applicationSuspended:
                print("Application suspended")
            case .idleTimeout:
                print("Idle timeout")
            case .systemError:
                print("System error")
            case .notifyWhenFinished:
                print("Playback finished")
            case .gameControllerDisconnect:
                print("Controller disconnected.")
            case .engineDestroyed:
                print("Engine destroyed.")
            @unknown default:
                print("Unknown error")
            }
        }
        
        // The reset handler provides an opportunity to restart the engine.
        engine?.resetHandler = {

            print("Reset Handler: Restarting the engine.")

            do {
                // Try restarting the engine.
                try self.engine?.start()


            } catch {
                print("Failed to start the engine")
            }
        }
        
        // Start the haptic engine for the first time.
        do {
            try self.engine?.start()
        } catch {
            print("Failed to start the engine: \(error)")
        }
    }
    
    // Play a haptic transient pattern at the given time, intensity, and sharpness.
    private func playHapticTransient(time: TimeInterval) {
    
        // Abort if the device doesn't support haptics.
        if !supportsHaptics {
            return
        }
        
        // Define custom "heart beat" pattern
        let heartBeatHaptic1: (sharpness: Float, intensity: Float) = (sharpness: 0.05, intensity: 1.00) // set custom haptic pattern for first part of heartbeat
        let heartBeatHaptic2: (sharpness: Float, intensity: Float) = (sharpness: 0.15, intensity: 0.80) // set custom haptic pattern for second part of heartbeat

        
        // Create an event (static) parameter to represent the haptic's intensity and sharpness
        let intensityParameter1 = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                         value: heartBeatHaptic1.intensity)
        let sharpnessParameter1 = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                        value: heartBeatHaptic1.sharpness)
        let intensityParameter2 = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                         value: heartBeatHaptic2.intensity)
        let sharpnessParameter2 = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                        value: heartBeatHaptic2.sharpness)
        
        // Create an event to represent the transient haptic pattern.
        let event1 = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensityParameter1, sharpnessParameter1],
                                  relativeTime: 0)
        let event2 = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [intensityParameter2, sharpnessParameter2],
                                  relativeTime: 0.3)
        
        // Create a pattern from the haptic event.
        do {
            let pattern = try CHHapticPattern(events: [event1, event2], parameters: [])
            
            // Create a player to play the haptic pattern.
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate) // Play now.
            
            print("Created heart beat pattern")
        } catch let error {
            print("Error creating a haptic transient pattern: \(error)")
        }
    }
    
    
    
    // MARK: - Selectors
    @objc func playPauseButtonPressed(_ sender: UIButton) {

        // If not currently playing, play the audio and haptic pattern. Otherwise, pause it.
        if !isPlaying {
            playAudio() // Play audio
            
            playHapticTransient(time: CHHapticTimeImmediate) // Play heart beat pattern
         
            // Continue to play heart beat pattern every 0.9 seconds
            burstTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true, block: { [weak self] (_) in
                self?.playHapticTransient(time: CHHapticTimeImmediate)
               
            })
        } else {
            
            pauseAudio()  // Pause audio
            burstTimer?.invalidate() // Stop the heart beat haptic pattern
        }
        
    }


}

