//
//  ViewController.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/26/23.
//

import Foundation
import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet weak private var previewView: UIView!
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    var rootLayer: CALayer! = nil
    var bufferSize: CGSize = .zero
    var camera: CameraManager = CameraManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        camera.setupCamera()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        
        // Add layer to hierarchy
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        
        // Get dimensions of preview
        let dimensions = CMVideoFormatDescriptionGetDimensions((camera.videoCaptureDevice?.activeFormat.formatDescription)!)
        bufferSize.width = CGFloat(dimensions.height)
        bufferSize.height = CGFloat(dimensions.width)
    }
}
