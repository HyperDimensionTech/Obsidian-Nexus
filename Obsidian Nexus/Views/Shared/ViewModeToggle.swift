import SwiftUI

/**
 A toggle control for switching between List and Card view modes.
 
 Provides a consistent interface across the app for view mode switching
 with proper styling and accessibility support.
 */
struct ViewModeToggle: View {
    @Binding var viewMode: ViewMode
    
    var body: some View {
        Menu {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewMode = mode
                    }
                } label: {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                        
                        if viewMode == mode {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: viewMode.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("View Mode")
        .accessibilityValue(viewMode.displayName)
        .accessibilityHint("Tap to change view mode")
    }
}

/**
 A segmented control version of the view mode toggle for prominent placement.
 */
struct ViewModeSegmentedToggle: View {
    @Binding var viewMode: ViewMode
    
    var body: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(ViewMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.iconName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }
}

#Preview {
    VStack(spacing: 20) {
        ViewModeToggle(viewMode: .constant(.list))
        ViewModeSegmentedToggle(viewMode: .constant(.card))
    }
    .padding()
} 