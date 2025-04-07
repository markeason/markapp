import Foundation
import Speech
import AVFoundation
import UIKit

class TranscriptionManager: NSObject, ObservableObject {
    @Published var transcript: String = ""
    @Published var audioLevels: [CGFloat] = Array(repeating: 0.05, count: 30)
    @Published var isRecording: Bool = false
    @Published var permissionGranted: Bool = false
    @Published var errorMessage: String?
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var levelUpdateTimer: Timer?
    private var isStoppingRecording = false
    private var shouldResumeRecordingWhenActive = false
    private var bufferCounter = 0
    private var previousTranscript: String = ""
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        checkPermissions()
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        // Add observers for app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func setupSpeechRecognizer() {
        // Create speech recognizer with user's locale
        let locale = Locale.current
        print("Setting up speech recognizer with locale: \(locale.identifier)")
        
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        if speechRecognizer == nil {
            // Try with English as a fallback
            print("Failed to create speech recognizer with current locale, trying en-US")
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        if let recognizer = speechRecognizer {
            print("Speech recognizer created with locale: \(recognizer.locale.identifier)")
            // Check if the recognizer is available
            if !recognizer.isAvailable {
                print("Speech recognizer is not available right now")
                errorMessage = "Speech recognition is temporarily unavailable. Please try again later."
            }
        } else {
            print("Failed to create speech recognizer")
            errorMessage = "Speech recognition is not supported on this device."
        }
    }
    
    @objc private func handleAppWillResignActive() {
        // Mark that we should resume recording when app becomes active again
        shouldResumeRecordingWhenActive = isRecording
        
        // When going to background, we need to make sure the audio session is properly configured
        if isRecording {
            do {
                // Use a simpler, more compatible configuration for background recording
                print("Configuring audio session for background operation")
                
                let audioSession = AVAudioSession.sharedInstance()
                
                // Use playAndRecord with mixWithOthers to work better in background
                try audioSession.setCategory(
                    .playAndRecord, 
                    options: [.mixWithOthers, .defaultToSpeaker]
                )
                
                // Use default mode rather than a specific mode
                try audioSession.setMode(.default)
                
                // Ensure the session stays active
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                print("Audio session configured for background recording")
            } catch {
                print("Failed to configure audio session for background: \(error.localizedDescription)")
                
                // If we failed to configure for background, it's safer to stop recording
                shouldResumeRecordingWhenActive = true
                stopRecording()
            }
        }
    }
    
    @objc private func handleAppDidBecomeActive() {
        if shouldResumeRecordingWhenActive && !isRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startRecording()
            }
        }
        shouldResumeRecordingWhenActive = false
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began, save state
            shouldResumeRecordingWhenActive = isRecording
            stopRecording()
            
        case .ended:
            // Interruption ended, check if we should resume
            if shouldResumeRecordingWhenActive,
               let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                startRecording()
                shouldResumeRecordingWhenActive = false
            }
            
        @unknown default:
            break
        }
    }
    
    private func checkPermissions() {
        print("Checking speech recognition and microphone permissions")
        
        // First check speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                let isAuthorized = status == .authorized
                print("Speech recognition authorization status: \(status.rawValue) (authorized: \(isAuthorized))")
                
                if !isAuthorized {
                    switch status {
                    case .denied:
                        self.errorMessage = "Speech recognition permission denied. Please enable in Settings."
                    case .restricted:
                        self.errorMessage = "Speech recognition is restricted on this device."
                    case .notDetermined:
                        self.errorMessage = "Speech recognition permission not determined."
                    default:
                        self.errorMessage = "Speech recognition not available."
                    }
                }
                
                // Now check microphone permission
                if #available(iOS 17.0, *) {
                    // Use the new API for iOS 17 and later
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            print("Microphone permission granted: \(granted)")
                            
                            if !granted {
                                self.errorMessage = "Microphone access denied. Please enable in Settings."
                            }
                            
                            // Set overall permission status (both must be true)
                            self.permissionGranted = isAuthorized && granted
                            print("Overall permission status: \(self.permissionGranted)")
                            
                            // If permissions are granted but we still have an error message from before, clear it
                            if self.permissionGranted && self.errorMessage != nil && 
                               (self.errorMessage?.contains("permission") ?? false) {
                                self.errorMessage = nil
                            }
                        }
                    }
                } else {
                    // Use the deprecated API for older iOS versions
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            print("Microphone permission granted: \(granted)")
                            
                            if !granted {
                                self.errorMessage = "Microphone access denied. Please enable in Settings."
                            }
                            
                            // Set overall permission status (both must be true)
                            self.permissionGranted = isAuthorized && granted
                            print("Overall permission status: \(self.permissionGranted)")
                            
                            // If permissions are granted but we still have an error message from before, clear it
                            if self.permissionGranted && self.errorMessage != nil && 
                               (self.errorMessage?.contains("permission") ?? false) {
                                self.errorMessage = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    func startRecording() {
        // Check if we're already recording
        if isRecording {
            print("Already recording - ignoring start request")
            return
        }
        
        print("Starting speech recognition...")
        
        // Check permissions first
        if !permissionGranted {
            print("Permission not granted - cannot start recording")
            return
        }
        
        // Prevent concurrent operations when stopping
        guard !isStoppingRecording else { 
            print("Cannot start recording: currently stopping a previous recording")
            return 
        }
        
        print("Starting recording process")
        
        // If we have an existing audio engine, clean it up first
        if audioEngine != nil {
            print("Cleaning up existing audio engine before starting new one")
            stopRecording()
            
            // Wait a moment to ensure cleanup is complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.initializeAndStartRecording()
            }
        } else {
            // Start fresh
            initializeAndStartRecording()
        }
    }
    
    private func initializeAndStartRecording() {
        // Clear any previous error message
        errorMessage = nil
        
        // Initialize audio engine and recognition request
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine,
              let recognitionRequest = recognitionRequest else {
            errorMessage = "Failed to initialize audio engine"
            print("Error: Could not create audio engine or recognition request")
            return
        }
        
        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognizer not available"
            print("Error: Speech recognizer is nil")
            return
        }
        
        // Debug: Print speech recognizer details
        print("Speech recognizer details:")
        print("- Available: \(speechRecognizer.isAvailable)")
        print("- Locale: \(speechRecognizer.locale.identifier)")
        
        // Configure audio session properly BEFORE getting the input node format
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Debug: Print current audio session state
            print("Current audio session:")
            print("- Category: \(audioSession.category.rawValue)")
            print("- Mode: \(audioSession.mode.rawValue)")
            print("- Sample rate: \(audioSession.sampleRate)")
            print("- Input available: \(audioSession.isInputAvailable)")
            
            // First deactivate the session to reset previous state
            print("Deactivating previous audio session")
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Use a simpler category that's more likely to work
            print("Setting audio session category")
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set mode with less restrictive settings
            print("Setting audio session mode")
            try audioSession.setMode(.default)
            
            // Now activate the session
            print("Activating audio session")
            try audioSession.setActive(true)
            
            // Get available inputs after configuration
            if let availableInputs = audioSession.availableInputs {
                print("Available audio inputs:")
                for input in availableInputs {
                    print("- \(input.portName): \(input.portType.rawValue)")
                }
            } else {
                print("No available audio inputs!")
            }
            
            print("Audio session configured successfully")
        } catch {
            errorMessage = "Audio session configuration failed: \(error.localizedDescription)"
            print("Failed to configure audio session: \(error.localizedDescription)")
            stopRecording()
            return
        }
        
        // Important: Add task options to improve recognition
        recognitionRequest.shouldReportPartialResults = true
        
        // For better results in continuous recording
        recognitionRequest.taskHint = .dictation
        
        if #available(iOS 16, *) {
            // For newer iOS versions, we can set additional options
            recognitionRequest.addsPunctuation = true
        }
        
        // Now get the input node after proper audio session configuration
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        print("Starting speech recognition task...")
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var finalMessage: String?
            
            if let result = result {
                // Get the transcription
                let newTranscription = result.bestTranscription.formattedString
                print("Recognized text: \(newTranscription)")
                
                DispatchQueue.main.async {
                    // If we already have previous transcript, append the new text with a space
                    if !self.previousTranscript.isEmpty {
                        self.transcript = self.previousTranscript + " " + newTranscription
                    } else {
                        self.transcript = newTranscription
                    }
                }
            }
            
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                finalMessage = "Recognition error: \(error.localizedDescription)"
                
                // This might indicate that the recognition service is not working
                if self.transcript.isEmpty {
                    self.errorMessage = "Speech recognition unavailable. Please check your internet connection."
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // Only restart if we're still supposed to be recording
                if self.isRecording && !self.isStoppingRecording {
                    print("Recognition ended. Will restart with final message: \(finalMessage ?? "none")")
                    self.stopRecording()
                    // Don't restart immediately - add a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.startRecording()
                    }
                }
            }
        }
        
        // Log if recognition task wasn't created
        if recognitionTask == nil {
            print("ERROR: Failed to create recognition task")
            errorMessage = "Failed to start speech recognition"
            stopRecording()
            return
        }
        
        // Get the hardware format directly - crucial for preventing Input HW format is invalid errors
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        print("Using native hardware format: \(recordingFormat)")
        
        do {
            // Install tap using the hardware's native format
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
                guard let self = self, !self.isStoppingRecording else { return }
                
                // Log audio level for debugging
                if let firstChannel = buffer.floatChannelData?[0] {
                    let frameLength = Float(buffer.frameLength)
                    if frameLength > 0 {
                        let rms = sqrt(firstChannel.pointee * firstChannel.pointee / frameLength)
                        if rms > 0.1 {  // Only log when sound is detected
                            print("Audio level detected: \(rms)")
                        }
                    }
                }
                
                self.recognitionRequest?.append(buffer)
                
                // Process audio levels less frequently to reduce CPU load
                self.bufferCounter += 1
                if self.bufferCounter % 5 == 0 {
                    self.processAudioLevel(buffer: buffer)
                    if self.bufferCounter >= 100 {
                        self.bufferCounter = 0
                    }
                }
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            
            // Setup timer for updating audio levels UI
            levelUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.updateAudioLevels()
            }
            
            print("Audio engine started successfully")
        } catch {
            errorMessage = "Failed to start audio recording"
            print("Audio engine error: \(error.localizedDescription)")
            stopRecording()
        }
    }
    
    func stopRecording() {
        // Prevent redundant stops or stop when not recording
        guard !isStoppingRecording else { 
            print("Already stopping recording - ignoring duplicate request")
            return 
        }
        
        print("Stopping recording process")
        isStoppingRecording = true
        
        // Save the current transcript to preserve it for next recording session
        self.previousTranscript = self.transcript
        
        // Cancel any previous timers immediately
        if let timer = levelUpdateTimer {
            timer.invalidate()
            levelUpdateTimer = nil
            print("Invalidated level update timer")
        }
        
        // Update UI state immediately
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevels = Array(repeating: 0.05, count: 30)
        }
        
        // Then handle the audio engine cleanup on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Audio engine cleanup
            if let audioEngine = self.audioEngine {
                print("Stopping audio engine")
                
                // Stop the audio engine first
                audioEngine.stop()
                
                // Remove tap with error handling
                if audioEngine.isRunning {
                    do {
                        print("Removing audio tap")
                        try audioEngine.inputNode.removeTap(onBus: 0)
                    } catch {
                        print("Warning: Error removing audio tap: \(error.localizedDescription)")
                    }
                }
            } else {
                print("No audio engine to stop")
            }
            
            // Handle recognition request and task
            if let request = self.recognitionRequest {
                do {
                    print("Ending audio in recognition request")
                    try request.endAudio()
                } catch {
                    print("Warning: Error ending audio recognition: \(error.localizedDescription)")
                }
            }
            
            if let task = self.recognitionTask {
                print("Cancelling recognition task")
                task.cancel()
            }
            
            // Reset objects
            self.audioEngine = nil
            self.recognitionRequest = nil
            self.recognitionTask = nil
            self.bufferCounter = 0
            
            // Try to deactivate the audio session
            do {
                print("Deactivating audio session")
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Warning: Error deactivating audio session: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                print("Cleanup completed")
                self.isStoppingRecording = false
            }
        }
    }
    
    private func processAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        
        // Calculate RMS (root mean square) of the signal
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        
        // Convert to decibels and normalize
        let db = 20 * log10(rms)
        let normalizedLevel = max(0.05, min(1.0, CGFloat((db + 50) / 50))) // Normalize between 0 and 1
        
        DispatchQueue.main.async {
            self.audioLevels[0] = normalizedLevel
        }
    }
    
    private func updateAudioLevels() {
        DispatchQueue.main.async {
            // Shift all levels to the right
            for i in (1..<self.audioLevels.count).reversed() {
                self.audioLevels[i] = self.audioLevels[i-1]
            }
            
            // Add slight interpolation for smoother transitions between values
            if self.audioLevels.count > 1 {
                let currentLevel = self.audioLevels[0]
                let previousLevel = self.audioLevels[1]
                // Slightly smooth the transition
                self.audioLevels[0] = currentLevel * 0.7 + previousLevel * 0.3
            }
        }
    }
    
    func reset() {
        stopRecording()
        transcript = ""
        previousTranscript = ""
    }
} 