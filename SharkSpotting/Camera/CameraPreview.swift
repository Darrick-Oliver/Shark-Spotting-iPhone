//
//  CameraPreview.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/12/23.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        
        let view = UIView(frame: UIScreen.main.bounds)
        
        cameraManager.setupCamera()
        
        // Create a new AVCaptureVideoPreviewLayer and add it to the view
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        
        // Start the capture session
        cameraManager.startCapture()
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the preview layer's frame if the view's frame changes
        if uiView.bounds != context.coordinator.lastBounds {
            context.coordinator.lastBounds = uiView.bounds
            uiView.layer.sublayers?.first?.frame = uiView.layer.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lastBounds: CGRect = .zero
    }
}
