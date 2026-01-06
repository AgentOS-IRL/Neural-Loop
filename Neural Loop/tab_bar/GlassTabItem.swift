//
//  GlassTabItem.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import Foundation
import SwiftUI

struct GlassTabItem: View {
    @Environment(\.colorScheme) private var colorScheme

    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: .semibold))

                Text(tab.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(
                isSelected
                    ? (colorScheme == .dark ? .white : .black)
                    : (colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
            )
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? .thinMaterial : .ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.35)
                                        : Color.black.opacity(0.2),
                                    lineWidth: 0.8
                                )
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}
