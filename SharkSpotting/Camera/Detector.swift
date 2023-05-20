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

class ObjectDetector: CameraManager {
    
    private var request: VNCoreMLRequest!
    
    override func setupCamera() {
        super.setupCamera()
        
        // Load the Core ML model
        guard let model = try? VNCoreMLModel(for: best().model) else {
            fatalError("Failed to load model")
        }
        
        // Create a vision request with the model
        request = VNCoreMLRequest(model: model, completionHandler: handleDetection)
        request.imageCropAndScaleOption = .scaleFill
    }
    
    private func handleDetection(request: VNRequest, error: Error?) {
        // Handle the detection results here
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        // Handle the detection results here
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        // Create a shape layer for drawing bounding boxes
        let boundingBoxLayer = CAShapeLayer()
        boundingBoxLayer.frame = CGRect(x: 0, y: 0, width: previewLayer.frame.width, height: previewLayer.frame.height)
        previewLayer.addSublayer(boundingBoxLayer)
        
        // Loop over the detected objects and draw bounding boxes
        for result in results {
            // Get the object label and confidence score
            let label = result.labels[0].identifier
            let confidence = result.labels[0].confidence
            
            // Get the bounding box of the object in the coordinate space of the preview layer
            let boundingBox = result.boundingBox.scaled(to: previewLayer.frame.size)
            
            // Create a path for the bounding box
            let path = UIBezierPath(rect: boundingBox)
            
            // Create a shape layer for the bounding box
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.strokeColor = UIColor.red.cgColor
            shapeLayer.lineWidth = 2.0
            shapeLayer.fillColor = nil
            
            // Add the shape layer to the bounding box layer
            boundingBoxLayer.addSublayer(shapeLayer)
        }
    }
    
    func startDetection() {
        startCapture()
    }
    
    func stopDetection() {
        stopCapture()
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Run the vision request on the captured frame
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
