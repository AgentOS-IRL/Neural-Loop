import SwiftUI

struct NewWorkoutView: View {
    var body: some View {
        WorkoutTemplateEditorView(mode: .create)
    }
}

#Preview {
    NewWorkoutView()
}
