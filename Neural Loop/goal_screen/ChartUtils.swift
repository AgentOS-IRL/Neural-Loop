//
//  ChartUtils.swift
//  Neural Loop
//
//  Created by Sanjeev Hayal on 13/01/2026.
//
import SwiftUI
import Charts

struct FancyProgressBar: View {
    var totalProgress: Double
    var targetValue: Double

    @Environment(\.colorScheme) private var colorScheme

    private var clampedProgress: Double {
        min(max(totalProgress, 0), targetValue)
    }

    private var remaining: Double {
        max(targetValue - clampedProgress, 0)
    }

    private var pct: Double {
        targetValue == 0 ? 0 : (clampedProgress / targetValue)
    }

    private let barHeight: CGFloat = 18
    private let cornerRadius: CGFloat = 999

    private var trackTopColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12)
    }

    private var trackBottomColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.20) : Color.black.opacity(0.06)
    }

    private var backgroundTopColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.92)
    }

    private var backgroundBottomColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.black.opacity(0.06)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.06)
    }

    private var innerStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    private var hairlineStrokeColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.10)
    }

    private var hairlineBlendMode: BlendMode {
        colorScheme == .dark ? .overlay : .multiply
    }

    private var labelTextColor: Color {
        Color.primary.opacity(pct > 0.55 ? 1.0 : 0.82)
    }

    private var domainMax: Double {
        max(targetValue, 1)
    }

    private var headSize: CGFloat {
        let s = barHeight + 2
        return s * s
    }

    @ChartContentBuilder
    private var trackMark: some ChartContent {
        RectangleMark(
            xStart: .value("Start", 0),
            xEnd: .value("End", domainMax),
            yStart: .value("Y0", 0),
            yEnd: .value("Y1", 1)
        )
        .foregroundStyle(
            .linearGradient(
                colors: [
                    trackTopColor,
                    trackBottomColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(cornerRadius)
    }

    @ChartContentBuilder
    private var fillMark: some ChartContent {
        if clampedProgress > 0 {
            RectangleMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", clampedProgress),
                yStart: .value("Y0", 0),
                yEnd: .value("Y1", 1)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        Color.accentColor.opacity(0.95),
                        Color.accentColor.opacity(0.70),
                        Color.accentColor.opacity(0.55)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(cornerRadius)

            RectangleMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", clampedProgress),
                yStart: .value("GlossY0", 0.62),
                yEnd: .value("GlossY1", 0.98)
            )
            .foregroundStyle(.white.opacity(0.10))
            .cornerRadius(cornerRadius)
        }
    }

    @ChartContentBuilder
    private var headMark: some ChartContent {
        if clampedProgress > 0 && clampedProgress < domainMax {
            PointMark(
                x: .value("Head", clampedProgress),
                y: .value("Y", 0.5)
            )
            .symbol(Circle())
            .symbolSize(headSize)
            .foregroundStyle(
                .linearGradient(
                    colors: [
                        Color.accentColor.opacity(0.98),
                        Color.accentColor.opacity(0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(0.95)
        }
    }

    private var progressChart: some View {
        Chart {
            trackMark
            fillMark
            headMark
        }
        .chartXScale(domain: 0...domainMax)
        .chartYScale(domain: 0...1)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plotArea in
            plotArea.frame(height: barHeight)
        }
        .frame(height: 54)
        .clipShape(Capsule(style: .circular))
    }

    private var trackBackgroundView: some View {
        Capsule(style: .circular)
            .fill(
                .linearGradient(
                    colors: [
                        backgroundTopColor,
                        backgroundBottomColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: shadowColor, radius: 12, x: 0, y: 8)
            .overlay {
                Capsule(style: .circular)
                    .strokeBorder(innerStrokeColor, lineWidth: 1)
            }
    }

    private var hairlineOverlayView: some View {
        Capsule(style: .circular)
            .strokeBorder(hairlineStrokeColor, lineWidth: 0.8)
            .blendMode(hairlineBlendMode)
    }

    @ViewBuilder
    private func percentOverlay(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        let plotFrame = geo[proxy.plotAreaFrame]
        let proposedX = proxy.position(forX: clampedProgress)
        let rawX = proposedX ?? plotFrame.minX
        let clampedX = max(rawX, plotFrame.minX + 22)
        let x = min(clampedX, plotFrame.maxX - 22)
        let y = plotFrame.midY

        Text("\(Int(pct * 100))%")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(labelTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(innerStrokeColor, lineWidth: 1)
            }
            .shadow(color: shadowColor.opacity(colorScheme == .dark ? 0.75 : 0.55), radius: 6, x: 0, y: 2)
            .position(x: x, y: y)
    }

    var body: some View {
        progressChart
            .background { trackBackgroundView }
            .overlay { hairlineOverlayView }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    percentOverlay(proxy: proxy, geo: geo)
                }
            }
            .padding(.horizontal, 2)
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: totalProgress)
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: targetValue)
    }
}
