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
    @State private var isUtilityMenuPresented = false
    
    // MARK: - Touch-following hover bubble
    @State private var isTouchingBar: Bool = false
    @State private var hoveredTab: AppTab? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isUtilityMenuPresented {
                utilityMenu
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
                    .zIndex(1)
            }

            HStack(spacing: 12) {
                contentNavigationPill
                    .frame(maxWidth: .infinity)

                utilityActionButton
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 78, alignment: .bottom)
    }

    private var contentNavigationPill: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        
        return ZStack {
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
                                width: bubbleWidth(in: geo),
                                height: 44
                            )
                            .offset(x: bubbleX(for: hoveredTab, in: geo), y: 10)
                            .transition(.opacity)
                            .allowsHitTesting(false)
                    }

                    HStack(spacing: tabSpacing) {
                        ForEach(visibleTabs, id: \.self) { tab in
                            tabButton(tab)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
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
                                    isUtilityMenuPresented = false
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
    }

    private var utilityActionButton: some View {
        let shape = Circle()

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                isUtilityMenuPresented.toggle()
            }
        } label: {
            ZStack {
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

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.88))
                    .rotationEffect(.degrees(isUtilityMenuPresented ? 45 : 0))
            }
            .frame(width: 60, height: 60)
            .overlay {
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
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open utilities")
        .accessibilityHint("Shows settings and additional app actions.")
    }

    private var utilityMenu: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                selectedTab = .settings
                isUtilityMenuPresented = false
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: AppTab.settings.systemImage)
                    .font(.system(size: 17, weight: .semibold))

                Text(AppTab.settings.rawValue)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.88))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                ZStack {
                    if reduceTransparency {
                        shape
                            .fill(Color(.secondarySystemBackground).opacity(0.96))
                    } else {
                        GlassEffectContainer {
                            shape
                                .glassEffect(.clear.interactive(), in: shape)
                        }
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    }
                }
            }
            .overlay {
                shape
                    .strokeBorder(
                        (colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10),
                radius: 14,
                y: 8
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .padding(.trailing, 16)
        .offset(y: -76)
    }
    
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        
        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                selectedTab = tab
                isUtilityMenuPresented = false
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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(tabTextColor(isSelected))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 4)
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
    private var visibleTabs: [AppTab] {
        AppTab.contentTabs
    }

    private func tabSlotWidth(in geo: GeometryProxy) -> CGFloat {
        let tabCount = max(visibleTabs.count, 1)
        let availableWidth = geo.size.width - (horizontalPadding * 2) - (CGFloat(tabCount - 1) * tabSpacing)
        return max(availableWidth / CGFloat(tabCount), 1)
    }

    private func tabFromTouch(x: CGFloat, in geo: GeometryProxy) -> AppTab {
        let width = tabSlotWidth(in: geo)
        let normalizedX = x - horizontalPadding
        let idx = Int((normalizedX / max(width + tabSpacing, 1)).rounded(.down))
        let clamped = min(max(idx, 0), visibleTabs.count - 1)
        return visibleTabs[clamped]
    }

    private func tabSlotX(for tab: AppTab, in geo: GeometryProxy) -> CGFloat {
        let width = tabSlotWidth(in: geo)
        let idx = visibleTabs.firstIndex(of: tab) ?? 0
        return horizontalPadding + CGFloat(idx) * (width + tabSpacing)
    }

    private func bubbleWidth(in geo: GeometryProxy) -> CGFloat {
        max(tabSlotWidth(in: geo) - 2, 1)
    }

    private func bubbleX(for tab: AppTab, in geo: GeometryProxy) -> CGFloat {
        tabSlotX(for: tab, in: geo)
    }

    private var horizontalPadding: CGFloat {
        visibleTabs.count > 4 ? 10 : 14
    }

    private var tabSpacing: CGFloat {
        visibleTabs.count > 4 ? 2 : 6
    }
}
