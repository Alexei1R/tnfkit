// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

//
//  RecordLayerView.swift
//  Motionlink
//
//  Created by rusu alexei on 11.03.2025.
//

import Core
import Foundation
import Engine
import Foundation
import SwiftUI
import tnfkit

struct RecordLayerView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State var showPopUp: Bool = false
    
    var selectedCaracter : String = "robot"
    
    var body: some View {
        ZStack {
            // Black background to ensure we have black bars
            Color.black.edgesIgnoringSafeArea(.all)
            
            // AR body tracking view with character
#if os(iOS) && !targetEnvironment(macCatalyst)
            ARBodyTrackingView(
                onBodyTracking: { bodyAnchor in
                    viewModel.handleBodyTracking(bodyAnchor: bodyAnchor)
                },
                onFrame: { frame in
                    viewModel.handleFrame(frame: frame)
                },
                characterName: selectedCaracter
            )
            .edgesIgnoringSafeArea(.all)
            
#else
            // Fallback for macOS or platforms without ARKit body tracking
            Color.black
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    VStack(spacing: 12) {
                        Text("Camera Preview")
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .medium))
                        
                        Text("Body tracking requires iOS device with A12 chip or later")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                )
#endif
            
            // Recording controls
            VStack {
                Spacer()
                createRecordButton()
                    .padding(.bottom, 32)
            }
            .edgesIgnoringSafeArea(.bottom)
            
            // Popup overlay when visible
            if showPopUp {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        createEndScanPopUp()
                    )
            }
        }
    }
}

// Rest of the RecordLayerView implementation remains the same
private extension RecordLayerView {
    func createRecordButton() -> some View {
        Button(action: {
            if viewModel.isRecording {
                print("end")
                viewModel.endRecording()
                showPopUp = true
            } else {
                viewModel.startRecording()
                print("start")
            }
            viewModel.isRecording.toggle()
        }) {
            Image(systemName: viewModel.isRecording ? "square.fill" : "circle.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .padding(28)
                .foregroundStyle(.red)
                .background(
                    Circle()
                        .foregroundStyle(.black)
                        .opacity(0.7)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func createEndScanPopUp() -> some View {
        VStack(spacing: 18) {
            Text("Save Recording")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 20)
            
            VStack(spacing: 16) {
                //axes review
                TextField("", text: $viewModel.recordingName, prompt: Text("Default").foregroundColor(.gray))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Button(action: {
                    viewModel.saveRecording(name : viewModel.recordingName)
                    showPopUp = false
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                    )
                }
                
                Button(action: {
                    showPopUp = false
                }) {
                    Text("Cancel")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 16)
    }
}
