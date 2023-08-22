//
//  DetectorRefactored.swift
//  SharkSpotting
//
//  Created by Darrick Oliver on 8/6/23.
//

import UIKit
import CoreML
import Vision
import AVFoundation
import Photos

class ObjectDetectorRefactored: CameraManager {
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
    private var sawShark: Bool = false
    private var predictions: [[VNRecognizedObjectObservation]] = []
    private var presentationTime = CMTime.zero
    
    // Hardware Metrics
    private var metricsTimer: Timer?
    var totalCPUUsage: Double = 0.0
    private var accumulatedCPUUsage: Double = 0.0
    private var accumulatedCPUSamples: Int = 0
    var memoryUsage: UInt64 = 0
    
    func setupCamera(frame: CGRect) {
        super.setupCamera()
        setupPreviewLayer(frame: frame)
        loadModel()
        setupRequest()
    }
    
    private func setupPreviewLayer(frame: CGRect) {
        previewLayer = AVCaptureVideoPreviewLayer(session: super.session)
        previewLayer.frame = frame
    }
    
    private func loadModel() {
        guard let model = try? VNCoreMLModel(for: best(configuration: MLModelConfiguration()).model) else {
            fatalError("Failed to load model")
        }
        request = VNCoreMLRequest(model: model, completionHandler: handleDetection)
        request.imageCropAndScaleOption = .scaleFill
    }
    
    private func setupRequest() {
        inputImageSize = CGSize(width: 640, height: 640) // Set your desired input image size
    }

    private func handleDetection(request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            self.clearBoundingBoxesAndLabels()
            
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            
            self.sawShark = false
            for result in results {
                let label = result.labels[0].identifier
                let confidence = result.labels[0].confidence
                
                self.handleSharkDetection(label: label)
                self.drawBoundingBoxAndLabel(result: result, label: label, confidence: confidence)
                
                if self.sawShark && self.isRecording {
                    self.predictions.append(results)
                }
            }
        }
    }
    
    private func clearBoundingBoxesAndLabels() {
        for layer in boundingBoxLayers {
            layer.removeFromSuperlayer()
        }
        boundingBoxLayers.removeAll()
        
        for layer in labelLayers {
            layer.removeFromSuperlayer()
        }
        labelLayers.removeAll()
    }
    
    private func handleSharkDetection(label: String) {
        if !sawShark && label == "shark" {
            sawShark = true
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
    
    private func drawBoundingBoxAndLabel(result: VNRecognizedObjectObservation, label: String, confidence: VNConfidence) {
        let previewLayerSize = previewLayer.frame.size
        let boundingBox = getConvertedRect(boundingBox: result.boundingBox, inImage: inputImageSize, containedIn: previewLayerSize)
        
        let shapeLayer = createBoundingBoxShapeLayer(rect: boundingBox)
        previewLayer.addSublayer(shapeLayer)
        boundingBoxLayers.append(shapeLayer)
        
        let labelLayer = createLabelLayer(label: label, confidence: confidence, rect: boundingBox)
        previewLayer.addSublayer(labelLayer)
        labelLayers.append(labelLayer)
    }
    
    private func createBoundingBoxShapeLayer(rect: CGRect) -> CAShapeLayer {
        let path = UIBezierPath(rect: rect)
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = nil
        return shapeLayer
    }
    
    private func createLabelLayer(label: String, confidence: VNConfidence, rect: CGRect) -> CATextLayer {
        let labelLayer = CATextLayer()
        labelLayer.string = "\(label) (\(confidence))"
        labelLayer.fontSize = 14
        labelLayer.foregroundColor = UIColor.red.cgColor
        labelLayer.backgroundColor = UIColor.white.cgColor
        labelLayer.alignmentMode = .center
        labelLayer.frame = CGRect(x: rect.origin.x,
                                  y: rect.origin.y - 20,
                                  width: labelLayer.preferredFrameSize().width + 10,
                                  height: 20)
        return labelLayer
    }

}
