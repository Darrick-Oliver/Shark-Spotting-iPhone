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
    
    func toggleRecording() {
        if (!isRecording) {
            isRecording = true
            detector.startMetricRecording()
        } else {
            isRecording = false
            detector.stopMetricRecording()
        }
    }
    
    var body: some View {
        ZStack {
            CameraPreview(detector: detector)
                .ignoresSafeArea()
            
            VStack {
                Text("Average: \(detector.fps)")
                
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
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
