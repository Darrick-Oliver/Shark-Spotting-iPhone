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
    var isRecording: Bool = false
    
    // Detection
    private var boundingBoxLayers: [CAShapeLayer] = []
    private var labelLayers: [CATextLayer] = []
    private var inputImageSize: CGSize = CGSize(width: 0, height: 0)
    
    // FPS
    var fps: Double = 0.0
    private var framesProcessedDuringInterval: Int = 0
    
    // Video and predictions
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var videoWriterAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoURL: URL?
    private var predictionsFolderURL: URL?
    private var predictions: [[VNRecognizedObjectObservation]] = []
    private var presentationTime = CMTime.zero
    
    // Hardware Metrics
    private var metricsTimer: Timer?
    var totalCPUUsage: Double = 0.0
    private var accumulatedCPUUsage: Double = 0.0
    private var accumulatedCPUSamples: Int = 0
    var memoryUsage: UInt64 = 0
    
    // Setting up camera and model
    func setupCamera(frame: CGRect) {
        super.setupCamera()
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: super.session)
        self.previewLayer.frame = frame

        // Load the Core ML model
        guard let model = try? VNCoreMLModel(for: cow_best(configuration: MLModelConfiguration()).model) else {
            fatalError("Failed to load model")
        }

        // Create a vision request with the model
        self.request = VNCoreMLRequest(model: model, completionHandler: handleDetection)
        self.request.imageCropAndScaleOption = .scaleFill
        
        // Can't find a way to do this programmatically on a VNCoreMLModel...
        self.inputImageSize = CGSize(width: 640, height: 640)
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Run the vision request on the captured frame
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([self.request])
        
        self.framesProcessedDuringInterval += 1
        
        // Record frame if a shark is spotted and recording is enabled
        if isRecording, let videoWriterInput = videoWriterInput {
            if videoWriterInput.isReadyForMoreMediaData {
                videoWriterAdaptor?.append(pixelBuffer, withPresentationTime: self.presentationTime)
                self.presentationTime = CMTimeAdd(presentationTime, CMTimeMake(value:1, timescale: Int32(30)))
            }
        }
    }
    
    func getConvertedRect(boundingBox: CGRect, inImage imageSize: CGSize, containedIn containerSize: CGSize) -> CGRect {
        
        let rectOfImage: CGRect
        
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect { // image extends left and right
            let newImageWidth = containerSize.height * imageAspect // the width of the overflowing image
            let newX = -(newImageWidth - containerSize.width) / 2
            rectOfImage = CGRect(x: newX, y: 0, width: newImageWidth, height: containerSize.height)
            
        } else { // image extends top and bottom
            let newImageHeight = containerSize.width * (1 / imageAspect) // the width of the overflowing image
            let newY = -(newImageHeight - containerSize.height) / 2
            rectOfImage = CGRect(x: 0, y: newY, width: containerSize.width, height: newImageHeight)
        }
        
        let newOriginBoundingBox = CGRect(
        x: boundingBox.origin.x,
        y: 1 - boundingBox.origin.y - boundingBox.height,
        width: boundingBox.width,
        height: boundingBox.height
        )
        
        var convertedRect = VNImageRectForNormalizedRect(newOriginBoundingBox, Int(rectOfImage.width), Int(rectOfImage.height))
        
        // add the margins
        convertedRect.origin.x += rectOfImage.origin.x
        convertedRect.origin.y += rectOfImage.origin.y
        
        return convertedRect
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
            
            // Loop over the detected objects and draw bounding boxes
            for result in results {
                // Get the object label and confidence score
                let label = result.labels[0].identifier
                let confidence = result.labels[0].confidence
                
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
            
            if (self.isRecording) {
                self.predictions.append(results)
            }
        }
    }
    
    struct Prediction: Codable {
        let confidence: Double
        let identifier: String
    }
    
    private func savePredictionsToFile() {
        guard let folderUrl = predictionsFolderURL else {
            print("Predictions file URL is not initialized.")
            return
        }
        // Create file name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmssSSSS"
        let currentDate = Date()
        let formattedDate = dateFormatter.string(from: currentDate)
        let filename = "predictions_\(formattedDate).json"
        
        // Create url
        let fileUrl = folderUrl.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        
        let newPredictions = self.predictions.map { frame in
            return frame.map { prediction in
                return prediction.labels.map { label in
                    Prediction(confidence: Double(label.confidence), identifier: label.identifier)
                }
            }
        }
        
        do {
            let jsonData = try encoder.encode(newPredictions)
            try jsonData.write(to: fileUrl)
        } catch {
            print("Error saving predictions: \(error.localizedDescription)")
        }
    }
    
    
    // Original method inspired from: https://stackoverflow.com/questions/44744372/get-cpu-usage-ios-swift
    // Some modifications made to avoid allocation/deallocation
    func hostCPULoadInfo() -> host_cpu_load_info? {
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride/MemoryLayout<integer_t>.stride
        
        var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var cpuLoadInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        if result != KERN_SUCCESS{
            print("Error getting CPU info: \(result)")
            return nil
        }
        return cpuLoadInfo
    }
    
    private func updateFPS() {
        DispatchQueue.global(qos: .background).async {
            // Calculate FPS
            self.fps = Double(self.framesProcessedDuringInterval)
            
            // Print average FPS every second
            print("Average FPS: \(self.fps)")

            // Reset counters for the next interval
            self.framesProcessedDuringInterval = 0
        }
    }

    func getCPUUsage() {
        guard let load = hostCPULoadInfo() else {
            return
        }
        
        let userTicks = Double(load.cpu_ticks.0)
        let systemTicks = Double(load.cpu_ticks.1)
        let idleTicks = Double(load.cpu_ticks.2)
        let totalTicks = userTicks + systemTicks + idleTicks
        
        // Calculate CPU usage percentage for the interval
        if totalTicks > 0 {
            let usedTicks = userTicks + systemTicks
            let intervalCPUUsage = usedTicks / totalTicks
            self.accumulatedCPUUsage += intervalCPUUsage
            self.accumulatedCPUSamples += 1
        }
        
        // Calculate the average CPU usage
        if self.accumulatedCPUSamples > 0 {
            self.totalCPUUsage = self.accumulatedCPUUsage / Double(self.accumulatedCPUSamples)
        }
    }
    
    private func updateHardwareUsage() {
        DispatchQueue.global(qos: .background).async {
            self.getCPUUsage()
            self.getMemoryUsage()

            print("Average CPU Usage: \(self.totalCPUUsage * 100.0)%")
            print("Average Memory Usage: \(self.memoryUsage) bytes")

            self.accumulatedCPUUsage = 0.0
            self.accumulatedCPUSamples = 0
            
            self.savePredictionsToFile()
            self.predictions = []
        }
    }
    
    @objc private func updateMetrics() {
        updateHardwareUsage()
        updateFPS()
    }
    
    func getMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            self.memoryUsage = info.resident_size
        } else {
            print("Error getting memory usage: \(result)")
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
    private func setupVideoWriter() {
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

            // Save video writer and its input for later use
            self.videoWriter = assetWriter
            self.videoWriterInput = assetWriterInput
            self.videoWriterAdaptor = adaptor
            self.videoURL = videoURL
        } catch {
            print("Error creating the asset writer: \(error.localizedDescription)")
        }
    }
    
    private func setupPredictionsFolder() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let baseFolderName = "Predictions"
        var folderName = baseFolderName
        var folderIndex = 0

        // Find the earliest available folder index
        while FileManager.default.fileExists(atPath: documentsDirectory.appendingPathComponent(folderName).path) {
            folderIndex += 1
            folderName = "\(baseFolderName)_\(folderIndex)"
        }
        
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        
        do {
            // Create the folder if it doesn't exist
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating predictions folder: \(error.localizedDescription)")
            return
        }
        
        self.predictionsFolderURL = folderURL
    }


    func startMetricRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Start recording
            self.isRecording = true
            self.setupVideoWriter()
            self.setupPredictionsFolder()
            self.predictions = []
            self.presentationTime = CMTime.zero
            
            // Reset any metrics
            self.accumulatedCPUUsage = 0.0
            self.accumulatedCPUSamples = 0
            self.framesProcessedDuringInterval = 0
        }
        
        // Start timer to avoid buffer overflow
        DispatchQueue.main.async {
            self.metricsTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateMetrics), userInfo: nil, repeats: true)
            RunLoop.main.add(self.metricsTimer!, forMode: .common)
        }
    }
    
    func stopMetricRecording() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.isRecording = false
            
            // Stop the metrics timer
            self.metricsTimer?.invalidate()
            self.metricsTimer = nil
            
            // Print metrics
            print("-== METRICS ==-")
            print("Final Average fps: \(self.fps)")
            print("Final Average CPU Usage: \(self.totalCPUUsage * 100.0)%")
            
            // Save predictions and metrics
            self.savePredictions()
            self.saveHardwareMetrics()
        }
    }
    
    private func saveHardwareMetrics() {
        // TODO: Implemnent this
    }

    private func savePredictions() {
        // Save the recorded video
        guard let videoURL = self.videoURL else {
            print("No video URL found.")
            return
        }
        
        func saveVideo() {
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
        }
        
        if let assetWriter = self.videoWriter {
            assetWriter.finishWriting {
                if assetWriter.status == .completed {
                    saveVideo()
                } else {
                    if let error = assetWriter.error {
                        print("Error saving the video: \(error.localizedDescription)")
                    } else {
                        print("Unknown error occurred while saving the video.")
                    }
                }
            }
        }
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
