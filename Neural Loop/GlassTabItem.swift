//
//  GlassTabItem.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 04/01/2026.
//

import Foundation
import SwiftUI

struct GlassTabItem: View {
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
            .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}
