// Copyright (c) 2025 The Noughy Fox
// 
// This software is released under the MIT License.
// https://opensource.org/licenses/MIT

import Core
import Engine
import Foundation
import SwiftUI
import tnfkit

final class SceneManagement: ObservableObject {
    @Published var sceneManager: SceneManager = .shared
    
    func createEntity(named name: String? = nil) -> Entity {
        let entity = sceneManager.scene.create(named: name)
        return entity
    }
    
    func addComponent<T: Component>(_ component: T, _ entity: Entity) -> T {
        sceneManager.scene.add(component, to: entity)
    }
    
    func getAllEntityNames() -> [String] {
        return Array(sceneManager.scene.namedEntities.keys)
    }
}

struct ObjectLayerView: View {
    @StateObject private var viewModel: SceneManagement = .init()
    
    // Text input state
    @State private var inputText: String = "model"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Object")
                .font(.headline)
                .padding(.bottom, 4)
            
            HStack(spacing: 10) {
                TextField("Enter object", text: $inputText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                // Add button
                Button(action: {
                    if !inputText.isEmpty {
                        let entity = viewModel.createEntity(named: UUID().uuidString)
                        viewModel.addComponent(MeshComponent(name: inputText), entity)
                        inputText = ""
                    }
                }) {
                    Text("Add")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(inputText.isEmpty ? Color.blue.opacity(0.6) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(inputText.isEmpty)
            }
            
            ScrollView {
                VStack {
                    // Display all entity names
                    ForEach(viewModel.getAllEntityNames(), id: \.self) { entityName in
                        Text(entityName)
                            .font(.subheadline)
                            .padding(4)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}
