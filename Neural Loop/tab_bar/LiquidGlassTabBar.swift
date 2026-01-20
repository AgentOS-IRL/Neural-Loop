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
    
    // MARK: - Touch-following hover bubble
    @State private var isTouchingBar: Bool = false
    @State private var hoveredTab: AppTab? = nil
    
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
                        .glassEffect(.clear.interactive(), in: shape)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            
            // Foreground content (no glass applied here)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Touch-following bubble (appears while finger is down)
                    if isTouchingBar, let hoveredTab {
                        touchFollowBubble
                            .frame(
                                width: tabSlotWidth(in: geo) - 8,
                                height: 44
                            )
                            .offset(x: tabSlotX(for: hoveredTab, in: geo) + 4, y: 10)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    HStack(spacing: 6) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            tabButton(tab)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .compositingGroup() // keeps text + SF Symbols sharp over glass
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            isTouchingBar = true
                            hoveredTab = tabFromTouch(x: value.location.x, in: geo)
                        }
                        .onEnded { _ in
                            if let hoveredTab {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                                    selectedTab = hoveredTab
                                }
                            }
                            withAnimation(.easeOut(duration: 0.18)) {
                                isTouchingBar = false
                            }
                        }
                )
            }
            .frame(height: 78) // match the tab bar height so GeometryReader doesn't expand
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
                if isSelected && !isTouchingBar {
                    interactiveBubble
                        .matchedGeometryEffect(id: "selectionBubble", in: glassNS)
                }
            }
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
    
    // MARK: - Interactive Liquid Glass Bubble
    private var interactiveBubble: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                reduceTransparency
                ? AnyShapeStyle(Color(.secondarySystemBackground))
                : AnyShapeStyle(.clear)
            )
            .glassEffect(
                .regular
                    .tint(.white.opacity(colorScheme == .dark ? 0.20 : 0.30))
                    .interactive(),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
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
        // Specular highlight for a liquid feel
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
        // Subtle lift shadow
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
                radius: 8,
                y: 4
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .scaleEffect(1.02)
    }

    // MARK: - Touch Follow Bubble (appears while finger is down)
    private var touchFollowBubble: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                reduceTransparency
                    ? AnyShapeStyle(Color(.secondarySystemBackground))
                    : AnyShapeStyle(.clear)
            )
            .glassEffect(
                
                .clear
                    .interactive(),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        (colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : 0.08),
                radius: 10,
                y: 6
            )
    }

    // MARK: - Touch -> Tab mapping helpers
    private func tabSlotWidth(in geo: GeometryProxy) -> CGFloat {
        let total = geo.size.width
        return total / CGFloat(AppTab.allCases.count)
    }

    private func tabFromTouch(x: CGFloat, in geo: GeometryProxy) -> AppTab {
        let width = tabSlotWidth(in: geo)
        let idx = Int((x / max(width, 1)).rounded(.down))
        let clamped = min(max(idx, 0), AppTab.allCases.count - 1)
        return AppTab.allCases[clamped]
    }

    private func tabSlotX(for tab: AppTab, in geo: GeometryProxy) -> CGFloat {
        let width = tabSlotWidth(in: geo)
        let idx = AppTab.allCases.firstIndex(of: tab) ?? 0
        return CGFloat(idx) * width
    }
}
