import SwiftUI

struct ThemedCard<Content: View>: View {
    var content: Content
    var gradient: LinearGradient = FleetingNotesTheme.cardGradient

    init(gradient: LinearGradient = FleetingNotesTheme.cardGradient, @ViewBuilder content: () -> Content) {
        self.gradient = gradient
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .fill(gradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FleetingNotesTheme.Metrics.cardCornerRadius, style: .continuous)
                .stroke(FleetingNotesTheme.borderGradient, lineWidth: 1)
        )
    }
}

struct ThemedRow<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.vertical, 8)
    }
}

struct ThemedTextField: View {
    var placeholder: String
    @Binding var text: String
    var isTitle: Bool = false

    var body: some View {
        TextField(placeholder, text: $text, axis: isTitle ? .horizontal : .vertical)
            .font(isTitle ? .title3.weight(.semibold) : .body)
            .foregroundColor(FleetingNotesTheme.textPrimary)
            .tint(FleetingNotesTheme.accentColor)
    }
}

extension View {
    func themedSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(FleetingNotesTheme.textSecondary)
            .padding(.leading, 16)
            .padding(.bottom, 4)
    }
}
