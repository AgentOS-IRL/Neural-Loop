//
//  LiquidGlassTabBar.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 20/01/2026.
//


import SwiftUI

struct LiquidGlassTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @Binding var selectedTab: AppTab
    @Namespace private var glassNS

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)

        ZStack {
            // ✅ Render the glass surface *behind* the content so icons/text stay crisp.
            if reduceTransparency {
                shape
                    .fill(Color(.secondarySystemBackground).opacity(0.95))
            } else {
                GlassEffectContainer {
                    shape
                        .glassEffect(.clear, in: shape)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }

            // Foreground content (no glass applied here)
            HStack(spacing: 6) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .compositingGroup() // keeps text + SF Symbols sharp over glass
        }
        .overlay {
            // Subtle edge so icons/text stay readable on bright backgrounds
            shape
                .strokeBorder(
                    (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)),
                    lineWidth: 1
                )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
            radius: 14,
            y: 8
        )
        .frame(height: 78) // ✅ keep tab bar compact (prevents full-screen expansion)
        .padding(.horizontal, 16)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        tabIconPrimary(isSelected),
                        tabIconSecondary(isSelected)
                    )
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.25 : 0.12),
                        radius: 3,
                        y: 1
                    )

                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(tabTextColor(isSelected))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(alignment: .center) {
                if isSelected {
                    // Liquid Glass selection bubble replaced with non-glass highlight
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            (colorScheme == .dark)
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.08)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    (colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.14)),
                                    lineWidth: 1
                                )
                        }
                        .matchedGeometryEffect(id: "selectionBubble", in: glassNS)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tabIconPrimary(_ isSelected: Bool) -> Color {
        if isSelected {
            return (colorScheme == .dark) ? .white : .black
        } else {
            // Higher contrast for visibility
            return (colorScheme == .dark) ? .white.opacity(0.92) : .black.opacity(0.88)
        }
    }

    private func tabIconSecondary(_ isSelected: Bool) -> Color {
        if isSelected {
            return (colorScheme == .dark) ? .white.opacity(0.78) : .black.opacity(0.70)
        } else {
            return (colorScheme == .dark) ? .white.opacity(0.62) : .black.opacity(0.55)
        }
    }

    private func tabTextColor(_ isSelected: Bool) -> Color {
        if isSelected {
            return (colorScheme == .dark) ? .white.opacity(0.92) : .black.opacity(0.92)
        } else {
            return (colorScheme == .dark) ? .white.opacity(0.70) : .black.opacity(0.68)
        }
    }
}
