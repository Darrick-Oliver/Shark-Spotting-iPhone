//
//  CameraPreview.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/12/23.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var detector: ObjectDetector
    
    func makeUIView(context: Context) -> UIView {
        
        let view = UIView(frame: UIScreen.main.bounds)
        
        detector.setupCamera()
        
        // Add previewLayer to view
        detector.previewLayer.videoGravity = .resizeAspectFill
        detector.previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(detector.previewLayer)
        
        // Start the capture session on the main thread
        DispatchQueue.main.async {
            detector.startDetection()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer's frame if the view's frame changes
        if uiView.bounds != context.coordinator.lastBounds {
            context.coordinator.lastBounds = uiView.bounds
            
            // Perform the UI update on the main thread
            DispatchQueue.main.async {
                uiView.layer.sublayers?.first?.frame = uiView.layer.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lastBounds: CGRect = .zero
    }
}
