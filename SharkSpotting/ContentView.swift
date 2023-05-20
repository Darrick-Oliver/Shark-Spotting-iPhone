//
//  ContentView.swift
//  SharkSpotting
//
//  Created by StudentAccount on 4/5/23.
//

import SwiftUI

struct ContentView: View {
    @StateObject var cameraManager = CameraManager()
    
    var body: some View {
        CameraPreview(cameraManager: cameraManager)
            .ignoresSafeArea()
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
