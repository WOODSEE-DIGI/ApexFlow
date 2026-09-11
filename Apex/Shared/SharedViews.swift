import SwiftUI
import Charts

// MARK: - Horizontal meter bar
struct MeterView: View {
    let value: Double      // 0.0–1.0
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.surface1)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(value, 1))))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Mini sparkline chart
struct SparklineView: View {
    let data: [DataPoint]
    let color: Color
    var domain: ClosedRange<Double>? = nil
    var height: CGFloat = 30

    private var yDomain: ClosedRange<Double> {
        if let d = domain { return d }
        let maxVal = data.map(\.value).max() ?? 1
        return 0...max(maxVal, 1)
    }

    var body: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Time", point.time),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [color.opacity(0.8), color.opacity(0.1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            LineMark(
                x: .value("Time", point.time),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain)
        .frame(height: height)
    }
}

// MARK: - Signal bar indicator (WiFi/BT style)
struct SignalBarView: View {
    let bars: Int     // 0–4 filled
    let total: Int    // usually 4
    let color: Color

    init(bars: Int, total: Int = 4, color: Color = Theme.wifiColor) {
        self.bars = bars
        self.total = total
        self.color = color
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < bars ? color : Theme.surface1)
                    .frame(width: 4, height: CGFloat(5 + i * 4))
            }
        }
    }
}

// MARK: - Speed badge
struct SpeedBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color.opacity(0.4), lineWidth: 0.5)
            )
    }
}

// MARK: - Stat label (key: value)
struct StatLabel: View {
    let key: String
    let value: String
    var valueColor: Color = Theme.text

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.overlay1)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(valueColor)
        }
    }
}
