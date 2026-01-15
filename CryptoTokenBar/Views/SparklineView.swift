import SwiftUI

struct SparklineView: View {
    let points: [Double]
    var lineColor: Color? = nil
    var lineWidth: CGFloat = 1.5
    var changePercent: Decimal? = nil
    
    var body: some View {
        GeometryReader { geo in
            let renderPoints = points.count >= 2 ? points : fallbackPoints
            if renderPoints.count > 1 {
                smoothPath(for: renderPoints, in: geo.size)
                    .stroke(
                        resolvedGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
    }
    
    private func smoothPath(for points: [Double], in size: CGSize) -> Path {
        Path { path in
            guard points.count > 1 else { return }
            
            let cgPoints = points.enumerated().map { index, value in
                CGPoint(
                    x: size.width * CGFloat(index) / CGFloat(points.count - 1),
                    y: size.height * (1 - value)
                )
            }
            
            path.move(to: cgPoints[0])
            
            for i in 1..<cgPoints.count {
                let prev = cgPoints[i - 1]
                let curr = cgPoints[i]
                let midX = (prev.x + curr.x) / 2
                path.addQuadCurve(to: curr, control: CGPoint(x: midX, y: prev.y))
            }
        }
    }
    
    private var resolvedGradient: LinearGradient {
        let isUp: Bool
        if points.count >= 2, let first = points.first, let last = points.last {
            isUp = last >= first
        } else if let change = changePercent {
            isUp = change >= 0
        } else {
            isUp = true
        }
        
        let colors: [Color] = isUp
            ? [Color(red: 0, green: 0.8, blue: 0.4), Color(red: 0, green: 1, blue: 0.53)]
            : [Color(red: 1, green: 0.3, blue: 0.3), Color(red: 1, green: 0.5, blue: 0.4)]
        
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
    
    private var resolvedColor: Color {
        if let color = lineColor { return color }
        if points.count >= 2, let first = points.first, let last = points.last {
            return last >= first ? .green : .red
        }
        if let change = changePercent {
            return change >= 0 ? .green : .red
        }
        return .gray
    }
    
    private var fallbackPoints: [Double] {
        guard let change = changePercent else {
            return [0.5, 0.5, 0.5, 0.5, 0.5]
        }
        let isUp = change >= 0
        if isUp {
            return [0.3, 0.25, 0.4, 0.35, 0.5, 0.45, 0.6, 0.55, 0.7]
        } else {
            return [0.7, 0.75, 0.6, 0.65, 0.5, 0.55, 0.4, 0.45, 0.3]
        }
    }
}

#Preview {
    SparklineView(points: [0.2, 0.5, 0.3, 0.7, 0.4, 0.8, 0.6])
        .frame(width: 40, height: 16)
}
