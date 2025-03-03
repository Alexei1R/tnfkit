//
//  ContentView.swift
//  Motionlink
//
//  Created by rusu alexei on 03.03.2025.
//

import SwiftUI
import tnfkit

struct ContentView: View {
    @State private var engine: TNFEngine?
    
    var body: some View {
        VStack {
            if let engine = engine {
                engine.createViewport().ignoresSafeArea()
            } else {
                Text("Initializing Metal engine...")
            }
            
        }
        .task {
            if engine == nil {
                engine = TNFEngine()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
