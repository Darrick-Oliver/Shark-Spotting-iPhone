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
    var previewLayer: AVCaptureVideoPreviewLayer!
    
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
    
    private func handleDetection(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            
            print(results)
            
            // Create a shape layer for drawing bounding boxes
            let boundingBoxLayer = CAShapeLayer()
            boundingBoxLayer.frame = CGRect(x: 0, y: 0, width: self.previewLayer.frame.width, height: self.previewLayer.frame.height)
            self.previewLayer.addSublayer(boundingBoxLayer)
            
            // Loop over the detected objects and draw bounding boxes
            for result in results {
                // Get the object label and confidence score
                let label = result.labels[0].identifier
                let confidence = result.labels[0].confidence
                
                print(result)
                
                // Get the bounding box of the object in the coordinate space of the preview layer
                let boundingBox = result.boundingBox.scaled(to: self.previewLayer.frame.size)
                
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
    }
    
    func startDetection() {
        DispatchQueue.global(qos: .userInitiated).async {
            super.startCapture()
        }
    }
    
    func stopDetection() {
        stopCapture()
    }
    
    // AVCaptureVideoDataOutputSampleBufferDelegate method
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Run the vision request on the captured frame
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([self.request])
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
