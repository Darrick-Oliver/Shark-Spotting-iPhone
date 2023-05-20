//
//  ContentView.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/5/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var detector = ObjectDetector()
    
    var body: some View {
        CameraPreview(detector: detector)
            .ignoresSafeArea()
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
