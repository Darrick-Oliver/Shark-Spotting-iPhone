//
//  ContentView.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/5/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var detector = ObjectDetector()
    @State private var isRecording: Bool = false
    @State private var startTime: Double = 0.0
    @State private var averageFPS: Double = 0.0
    @State private var averageCPUUsage: Double = 0.0
    @State private var memoryUsage: UInt64 = 0
    private let updateInterval: TimeInterval = 1.0 // Update interval in seconds
    
    func toggleRecording() {
        if (!isRecording) {
            isRecording = true
            detector.startMetricRecording()
        } else {
            isRecording = false
            detector.stopMetricRecording()
        }
    }
    
    // Function to update the FPS and CPU usage values
    func updateMetrics() {
        averageFPS = detector.fps
        averageCPUUsage = detector.totalCPUUsage
        memoryUsage = detector.memoryUsage
    }
    
    var body: some View {
        ZStack {
            CameraPreview(detector: detector)
                .ignoresSafeArea()
            
            VStack {
                Text("Average FPS: \(String(format: "%.2f", averageFPS))")
                Text("Average CPU Usage: \(String(format: "%.2f%%", averageCPUUsage * 100))")
                Text("Memory Usage: \(self.memoryUsage) bytes")
                
                Spacer()
                
                Button(action: toggleRecording) {
                    Text(isRecording ? "Stop recording" : "Start recording")
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .padding()
            }
        }
        .onAppear {
            // Start the timer to update metrics
            Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
                updateMetrics()
            }
        }
        .onDisappear {
            // Stop the timer when the view disappears
            Timer.cancelPreviousPerformRequests(withTarget: self)
        }
    }
}
