//
//  AssetLoadTask.swift
//  VideoRecorder
//
//  Created by Leo on 2016/12/16.
//  Copyright © 2016年 Binea. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation

//enum CameraFlashMode {
//    case light
//    case auto
//    case off
//}

class STRecoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    var audioDevice: AVCaptureDevice?
    var videoDevice: AVCaptureDevice?
    var audioDeviceInput: AVCaptureDeviceInput?
    var videoDeviceInput: AVCaptureDeviceInput?
    
    var captureSession: AVCaptureSession
    
    var videoOutput: AVCaptureVideoDataOutput
    var audioOutput: AVCaptureAudioDataOutput
    
    var assetWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?
    
    private(set) var isRecording: Bool = false
    private(set) var hasStartSession: Bool = false
    
    var outputUrl: URL
    
    var previewLayer: AVCaptureVideoPreviewLayer
    var previewView: UIView? {
        didSet {
            previewLayer.removeFromSuperlayer()
            if let view = previewView {
                previewLayer.frame = view.bounds
                view.layer.insertSublayer(previewLayer, at: 0)
            }
        }
    }
    private(set) var videoDevicePosition: AVCaptureDevicePosition = .back {
        didSet {
            if videoDevicePosition != oldValue {
                captureSession.beginConfiguration()
                if let videoDevice = STRecoder.videoDeviceForPosition(position: videoDevicePosition), let videoInput = try? AVCaptureDeviceInput(device: videoDevice) {
                    captureSession.removeInput(videoDeviceInput)
                    self.videoDevice = videoDevice
                    self.videoDeviceInput = videoInput
                    if captureSession.canAddInput(videoInput) {
                        captureSession.addInput(videoInput)
                    }
                }
                captureSession.commitConfiguration()
            }
        }
    }
    
    init(outputUrl: URL? = nil) {
        self.outputUrl = outputUrl ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Documents/recodVideos/\(UUID().uuidString).mp4")
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        if let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio), let audioInput = try? AVCaptureDeviceInput(device: audioDevice) {
            self.audioDevice = audioDevice
            self.audioDeviceInput = audioInput
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        }
        
        if let videoDevice = STRecoder.videoDeviceForPosition(position: videoDevicePosition), let videoInput = try? AVCaptureDeviceInput(device: videoDevice){
            self.videoDevice = videoDevice
            self.videoDeviceInput = videoInput
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        audioOutput = AVCaptureAudioDataOutput()
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        super.init()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        
        captureSession.startRunning()
    }
    
    deinit {
        captureSession.stopRunning()
    }
    
    func prepareToRecord() {
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            try? FileManager.default.removeItem(at: outputUrl)
        } else {
            try? FileManager.default.createDirectory(at: outputUrl.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        }
        
        let compressionProperties: [String : Any] = [AVVideoAverageBitRateKey : 1600000,
                                                     AVVideoExpectedSourceFrameRateKey : 30,
                                                     AVVideoMaxKeyFrameIntervalKey : 30]
        let videoSettings: [String : Any] = [AVVideoCodecKey : AVVideoCodecH264,
                                             AVVideoWidthKey : 640,
                                             AVVideoHeightKey : 480,
                                             AVVideoCompressionPropertiesKey: compressionProperties,
                                             AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill]
        
        let audioSettings: [String : Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
                                             AVSampleRateKey : Float(44100),
                                             AVNumberOfChannelsKey: 1]
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        videoInput?.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
        audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        self.assetWriter = try? AVAssetWriter(outputURL: self.outputUrl, fileType: AVFileTypeMPEG4)
        if let assetWriter = self.assetWriter {
            assetWriter.shouldOptimizeForNetworkUse = true
            if assetWriter.canAdd(videoInput!) {
                assetWriter.add(videoInput!)
            }
            if assetWriter.canAdd(audioInput!) {
                assetWriter.add(audioInput!)
            }
            assetWriter.startWriting()
        }
        hasStartSession = false
    }
    
    func startRecord() {
        if isRecording {
            return
        }
        if assetWriter == nil {
            prepareToRecord()
        }
        isRecording = true
    }
    
    func stopRecord(completionHandler handler: @escaping () -> Swift.Void) {
        if !isRecording {
            return
        }
        isRecording = false
        assetWriter?.finishWriting(completionHandler: { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.teardownAssetWriterAndInputs()
                handler()
            }
        })
    }
    
    func startRuning() {
        if captureSession.isRunning {
            return
        }
        captureSession.startRunning()
    }
    
    func stopRuning() {
        captureSession.stopRunning()
    }
    
    func switchCaptureDevices() {
        videoDevicePosition = videoDevice?.position == .back ? .front : .back
    }
    func setFlashMode(flashMode: AVCaptureFlashMode) {
        if let device = videoDevice, device.hasFlash {
            do {
                try device.lockForConfiguration()
                if flashMode == .on {
                    device.flashMode = .off
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                    device.flashMode = flashMode
                }
                device.unlockForConfiguration()
            } catch {
                
            }
        }
    }
    
    static func videoDeviceForPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
        guard let videoDevices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as? [AVCaptureDevice] else {
            return nil
        }
        for device in videoDevices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    func teardownAssetWriterAndInputs() {
        videoInput = nil
        audioInput = nil
        assetWriter = nil
    }
    
    //MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard isRecording else {
            return
        }
        var timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        timestamp.value += CMTimeValue(0.1 * Double(timestamp.timescale))
        if !hasStartSession {
            hasStartSession = true
            assetWriter?.startSession(atSourceTime: timestamp)
        }
        if captureOutput == videoOutput && videoInput?.isReadyForMoreMediaData ?? false {
            videoInput?.append(sampleBuffer)
        }
        if captureOutput == audioOutput && audioInput?.isReadyForMoreMediaData ?? false {
            audioInput?.append(sampleBuffer)
        }
    }
    
}
