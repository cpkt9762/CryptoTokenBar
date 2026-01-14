import SwiftUI

struct SparklineView: View {
    let points: [Double]
    var lineColor: Color = .green
    
    var body: some View {
        Canvas { context, size in
            guard points.count >= 2 else { return }
            
            let stepX = size.width / CGFloat(points.count - 1)
            
            var path = Path()
            for (index, point) in points.enumerated() {
                let x = CGFloat(index) * stepX
                let y = size.height * (1 - point)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(path, with: .color(lineColor), lineWidth: 1)
        }
    }
}

#Preview {
    SparklineView(points: [0.2, 0.5, 0.3, 0.7, 0.4, 0.8, 0.6])
        .frame(width: 40, height: 16)
}
