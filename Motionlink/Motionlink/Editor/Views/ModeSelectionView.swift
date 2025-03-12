import SwiftUI

struct ModeSelectorOption: View {
    var icon: String
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .frame(width: 18)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModeSelectorView: View {
    @ObservedObject var toolSelector: ToolSelector
    @State private var showMenu = false
    @State private var isLongPressing = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if showMenu {
                VStack(spacing: 0) {
                    ForEach(Mode.allCases) { mode in
                        ModeSelectorOption(
                            icon: mode.icon,
                            title: mode.rawValue,
                            isSelected: toolSelector.currentMode == mode
                        ) {
                            toolSelector.setMode(mode)
                            withAnimation(.spring()) {
                                showMenu = false
                            }
                        }
                        .padding(.vertical, 2)
                        
                        if mode != Mode.allCases.last {
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 6)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .offset(y: -5)
                .padding(.bottom, 30)
                .frame(width: 120)
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
            
            Button(action: {
                print("Selected mode: \(toolSelector.currentMode.rawValue)")
            }) {
                HStack(spacing: 8) {
                    Image(systemName: toolSelector.currentMode.icon)
                        .font(.system(size: 12, weight: .medium))
                    
                    Text(toolSelector.currentMode.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(showMenu ? 180 : 0))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 1)
                .scaleEffect(isLongPressing ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLongPressing)
            }
            .buttonStyle(PlainButtonStyle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            showMenu.toggle()
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isLongPressing = true }
                    .onEnded { _ in isLongPressing = false }
            )
        }
    }
}
