//
//  GlassTabBar.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//
import SwiftUI

struct GlassTabBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                GlassTabItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(colorScheme == .dark ? .ultraThinMaterial : .thinMaterial)

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                  ]
                                : [
                                    Color.black.opacity(0.25),
                                    Color.black.opacity(0.05),
                                    Color.clear
                                  ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(
            color: colorScheme == .dark
                ? .black.opacity(0.35)
                : .black.opacity(0.15),
            radius: 20,
            y: 10
        )
        .padding(.horizontal, 16)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(edges: .all)
        )
    }
}
