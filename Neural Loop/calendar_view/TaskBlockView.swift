import SwiftUI

struct TaskBlockView: View {
    let task: Tasks

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.caption)
                .bold()

            if let description = task.description {
                Text(description)
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .padding(8)
        .frame(height: taskHeight)
        .background(
            task.is_completed == true
            ? priorityColor.opacity(0.3)
            : priorityColor
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    task.is_completed == true
                    ? priorityColor.opacity(0.8)
                    : Color.clear,
                    style: StrokeStyle(lineWidth: 1.5, dash: task.is_completed == true ? [6] : [])
                )
        )
        .cornerRadius(8)
        .opacity(task.is_completed == true ? 0.6 : 1.0)
    }

    private var taskHeight: CGFloat {
        let duration = task.duration ?? 3600
        return CGFloat(duration) / 3600 * hourHeight
    }

    private var priorityColor: Color {
        switch task.priority {
        case 3: return Color.red.opacity(0.9)
        case 2: return Color.orange.opacity(0.9)
        case 1: return Color.blue.opacity(0.9)
        default: return Color.gray.opacity(0.7)
        }
    }
}

