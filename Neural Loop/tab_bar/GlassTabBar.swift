//
//  GlassTabBar.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//
import SwiftUI

struct GlassTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding var selectedTab: AppTab
    @Namespace private var glassNS

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.contentTabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassBase)
        .compositingGroup()
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
            radius: 14,
            y: 8
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Tab Button
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(foregroundStyle(isSelected))
            .padding(.vertical, 9)
            .background(alignment: .center) {
                if isSelected {
                    selectionBubble
                        .matchedGeometryEffect(id: "selectionBubble", in: glassNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Foreground
    private func foregroundStyle(_ isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return (colorScheme == .dark) ? AnyShapeStyle(.white) : AnyShapeStyle(.black)
        } else {
            return (colorScheme == .dark)
                ? AnyShapeStyle(.white.opacity(0.75))
                : AnyShapeStyle(.black.opacity(0.70))
        }
    }

    // MARK: - Base Glass
    private var glassBase: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                reduceTransparency
                    ? AnyShapeStyle(Color(.secondarySystemBackground))
                    : AnyShapeStyle(
                        // Glass material
                        colorScheme == .dark
                            ? AnyShapeStyle(.ultraThinMaterial.opacity(0.55))
                            : AnyShapeStyle(.ultraThinMaterial.opacity(0.45))
                    )
            )
            // Outer rim highlight for glass edge
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.22), Color.white.opacity(0.05), Color.clear]
                                : [Color.white.opacity(0.40), Color.black.opacity(0.05), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            // Specular “shine”
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.22),
                                Color.white.opacity(0.01),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
    }

    // MARK: - Selection Bubble
    private var selectionBubble: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                // Selected tab glass is a bit denser to stand out
                colorScheme == .dark
                    ? AnyShapeStyle(.ultraThinMaterial.opacity(0.65))
                    : AnyShapeStyle(.ultraThinMaterial.opacity(0.55))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.26), Color.white.opacity(0.05)]
                                : [Color.white.opacity(0.45), Color.black.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            }
            // Light shadow lift
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 8, y: 4)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }
}
