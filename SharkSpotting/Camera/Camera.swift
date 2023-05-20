//
//  Camera.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/12/23.
//

import Foundation
import AVFoundation

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    var videoCaptureDevice: AVCaptureDevice?
    private var input: AVCaptureInput?
    private let videoDataOut = AVCaptureVideoDataOutput()
    let dataOutputQueue = DispatchQueue(label: "VideoDataQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    let session = AVCaptureSession()
    
    @Published var isCapturing = false

    func setupCamera() {
        debugPrint("Requesting access")
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            if !response {
                return;
            }
        }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return; }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        self.videoCaptureDevice = videoCaptureDevice
        
        if (session.canAddInput(videoInput)) {
            session.addInput(videoInput)
            input = videoInput
        }
        
        if session.canAddOutput(videoDataOut) {
            session.addOutput(videoDataOut)
            videoDataOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoDataOut.setSampleBufferDelegate(self, queue: dataOutputQueue)
            videoDataOut.connection(with: .video)?.videoOrientation = .portrait
            videoDataOut.connection(with: .video)?.automaticallyAdjustsVideoMirroring = false
            videoDataOut.connection(with: .video)?.isVideoMirrored = true
        } else {
            debugPrint("Could not add video data output")
        }
    }
    
    func startCapture() {
        debugPrint("Start capture")
        
        guard isCapturing == false else { return }
        isCapturing = true
        
        #if arch(arm64)
        session.startRunning()
        #endif
    }
    
    func stopCapture() {
        debugPrint("Stop capture")
        guard isCapturing == true else { return }
        isCapturing = false

        #if arch(arm64)
        session.stopRunning()
        #endif
    }
}

