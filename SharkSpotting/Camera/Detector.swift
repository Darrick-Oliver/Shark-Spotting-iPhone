//
//  Detector.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/26/23.
//

import UIKit
import CoreML
import Vision
import AVFoundation
import Photos

class ObjectDetector: CameraManager {
    private var request: VNCoreMLRequest!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // Detection
    private var boundingBoxLayers: [CAShapeLayer] = []
    private var labelLayers: [CATextLayer] = []
    
    // FPS
    var isRecording: Bool = false
    var count: Int = 0
    var fps: Double = 0.0
    private var startTime: Double = 0.0
    
    // Video and predictions
    private var recordedFrames: [CVPixelBuffer] = []
    private var sawShark: Bool = false
    private var predictions: [[VNRecognizedObjectObservation]] = []
    
    // Setting up camera and model
    override func setupCamera() {
        super.setupCamera()
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: super.session)
        
        // Load the Core ML model
        guard let model = try? VNCoreMLModel(for: best(configuration: MLModelConfiguration()).model) else {
            fatalError("Failed to load model")
        }
        
        // Create a vision request with the model
        self.request = VNCoreMLRequest(model: model, completionHandler: handleDetection)
        self.request.imageCropAndScaleOption = .scaleFill
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Run the vision request on the captured frame
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([self.request])
        
        // Record frame if a shark is spotted
        if (sawShark && isRecording) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            var copy = pixelBuffer.copy()
            self.recordedFrames.append(copy)
        }
    }

    private func handleDetection(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            // Remove existing bounding box layers and label layers
            for layer in self.boundingBoxLayers {
                layer.removeFromSuperlayer()
            }
            self.boundingBoxLayers.removeAll()
            
            for layer in self.labelLayers {
                layer.removeFromSuperlayer()
            }
            self.labelLayers.removeAll()
            
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            
            // Take metrics if recording
            if (self.isRecording) {
                self.count += 1
            }
            
            // Loop over the detected objects and draw bounding boxes
            self.sawShark = false
            for result in results {
                // Get the object label and confidence score
                let label = result.labels[0].identifier
                let confidence = result.labels[0].confidence
                
                // Record if a shark was spotted
                if (!self.sawShark && label == "shark") {
                    self.sawShark = true
                }
                
                // Get the bounding box of the object in the coordinate space of the preview layer
                // TODO: Weird stuff is happening because camera input size != previewLayer output size
                // TODO: The camera is taking pictures that are wider than the previewlayer, causing the bounding boxes not to be scaled correctly
                let previewLayerSize = self.previewLayer.frame.size
                let boundingBox = result.boundingBox
                    .applying(CGAffineTransform(scaleX: previewLayerSize.width, y: previewLayerSize.height))

                // Create a path for the bounding box
                let path = UIBezierPath(rect: boundingBox)

                // Create a shape layer for the bounding box
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = path.cgPath
                shapeLayer.strokeColor = UIColor.red.cgColor
                shapeLayer.lineWidth = 2.0
                shapeLayer.fillColor = nil
                
                // Add the shape layer to the preview layer
                self.previewLayer.addSublayer(shapeLayer)
                self.boundingBoxLayers.append(shapeLayer)
                
                // Create a label layer to display the class prediction
                let labelLayer = CATextLayer()
                labelLayer.string = "\(label) (\(confidence))"
                labelLayer.fontSize = 14
                labelLayer.foregroundColor = UIColor.red.cgColor
                labelLayer.backgroundColor = UIColor.white.cgColor
                labelLayer.alignmentMode = .center
                let labelWidth = labelLayer.preferredFrameSize().width
                labelLayer.frame = CGRect(x: boundingBox.origin.x,
                                          y: boundingBox.origin.y - 20,
                                          width: labelWidth + 10,
                                          height: 20)
                
                // Add the label layer to the preview layer
                self.previewLayer.addSublayer(labelLayer)
                self.labelLayers.append(labelLayer)
            }
            
            if (self.sawShark && self.isRecording) {
                self.predictions.append(results)
            }
        }
    }
    
    func startDetection() {
        DispatchQueue.global(qos: .userInitiated).async {
            super.startCapture()
        }
    }
    
    func stopDetection() {
        DispatchQueue.global(qos: .userInitiated).async {
            super.stopCapture()
        }
    }
    
    func startMetricRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Initialize counts and start time
            self.count = 0
            self.startTime = Date().timeIntervalSince1970
            self.isRecording = true
            
            // Create new frame buffer and predictions for spotted sharks
            self.recordedFrames = []
            self.predictions = []
        }
    }
    
    func stopMetricRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.isRecording = false
            
            // Calculate metrics
            self.fps = Double(self.count) / (Date().timeIntervalSince1970 - self.startTime)
            
            // Print metrics
            print("-== METRICS ==-")
            print("Frames processed: \(self.count)")
            print("Frame count: \(self.recordedFrames.count)")
            print("Prediction count: \(self.predictions.count)")
            print("Average fps: \(self.fps)")
            
            // Send a prompt to save predictions
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Save Predictions", message: "Do you want to save \(self.predictions.count) predictions?", preferredStyle: .alert)
                
                let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
                    // Save recorded frames and predictions
                    self.saveRecordedFrames()
                    self.savePredictions()
                    
                    // TODO: Save all other metrics
                    // FPS, hardware metrics
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                            
                alertController.addAction(saveAction)
                alertController.addAction(cancelAction)
                
                // Show the alert
                guard let topViewController = UIApplication.shared.windows.first?.rootViewController else {
                    return
                }
                
                topViewController.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    private func saveRecordedFrames() {
        guard !self.recordedFrames.isEmpty else {
            print("No recorded frames to save.")
            return
        }

        // Create an asset writer to save the frames as a video
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = documentsDirectory.appendingPathComponent("SharkSpottingVideo.mov")
        
        // Check if the video file already exists at the specified URL
        if FileManager.default.fileExists(atPath: videoURL.path) {
            do {
                // Delete the existing video file
                try FileManager.default.removeItem(at: videoURL)
                print("Existing video file deleted.")
            } catch {
                print("Error deleting existing video file: \(error.localizedDescription)")
            }
        }

        do {
            let assetWriter = try AVAssetWriter(outputURL: videoURL, fileType: AVFileType.mov)

            let outputSettings = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: self.previewLayer.frame.size.width,
                AVVideoHeightKey: self.previewLayer.frame.size.height,
            ] as [String : Any]

            let assetWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)

            assetWriter.add(assetWriterInput)
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: .zero)

            var presentationTime = CMTime.zero

            // Iterate through each recorded frame and append it to the video
            for pixelBuffer in self.recordedFrames {
                while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.05)
                }

                if adaptor.assetWriterInput.isReadyForMoreMediaData {
                    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    presentationTime = CMTimeAdd(presentationTime, CMTimeMake(value: 1, timescale: Int32(fps)))
                }
            }

            assetWriter.finishWriting {
                if assetWriter.status == .completed {
                    // Save the video to the Photos library
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == .authorized {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                            }) { success, error in
                                if success {
                                    print("Video saved to Photos library.")
                                } else {
                                    print("Error saving video to Photos library: \(error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        } else {
                            print("Permission to access Photos library denied.")
                        }
                    }
                } else {
                    if let error = assetWriter.error {
                        print("Error saving the video: \(error.localizedDescription)")
                    } else {
                        print("Unknown error occurred while saving the video.")
                    }
                }
            }
        } catch {
            print("Error creating the asset writer: \(error.localizedDescription)")
        }
    }

    
    private func savePredictions() {
        // TODO: Implement the code to save predictions.
        // Iterate through the `self.predictions` array and save the bounding boxes and labels.
        // Ensure that the bounding boxes are scaled to the output size.
    }
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: origin.x * size.width,
            y: origin.y * size.height,
            width: size.width * width,
            height: size.height * height
        )
    }
}

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer {
        precondition(CFGetTypeID(self) == CVPixelBufferGetTypeID(), "copy() cannot be called on a non-CVPixelBuffer")

        var _copy : CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(self),
            CVPixelBufferGetHeight(self),
            CVPixelBufferGetPixelFormatType(self),
            nil,
            &_copy)

        guard let copy = _copy else { fatalError() }

        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
        CVPixelBufferLockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))


        let copyBaseAddress = CVPixelBufferGetBaseAddress(copy)
        let currBaseAddress = CVPixelBufferGetBaseAddress(self)

        memcpy(copyBaseAddress, currBaseAddress, CVPixelBufferGetDataSize(self))

        CVPixelBufferUnlockBaseAddress(copy, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly)


        return copy
    }
}
