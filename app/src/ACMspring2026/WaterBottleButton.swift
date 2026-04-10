//
//  WaterBottleButton.swift
//  ACMspring2026
//

import SwiftUI

// Trapezoid wider at the bottom, narrower at the top
private struct TrapezoidShape: Shape {
    let topWidth: CGFloat
    let bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = (bottomWidth - topWidth) / 2
        path.move(to: CGPoint(x: inset, y: 0))
        path.addLine(to: CGPoint(x: inset + topWidth, y: 0))
        path.addLine(to: CGPoint(x: bottomWidth, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct WaterBottleButton: View {
    let fillFraction: Double
    private let size = CGSize(width: 44, height: 54)

    private let lightBlue = Color(red: 0.53, green: 0.81, blue: 0.98)
    private let darkBlue  = Color(red: 0.0,  green: 0.25, blue: 0.55)

    private let threshold: Double = 0.80
    private var bodyWidth: CGFloat { size.width / 2 }
    private var neckWidth: CGFloat { size.width / 5 }
    private var totalHeight: CGFloat { size.height + 2 }

    private var rectHeight: CGFloat {
        totalHeight * CGFloat(min(fillFraction, threshold))
    }

    private var trapHeight: CGFloat {
        guard fillFraction > threshold else { return 0 }
        return totalHeight * CGFloat(fillFraction - threshold)
    }

    var body: some View {
        ZStack {
            // Outline provides the dark blue border
            Image(systemName: "waterbottle")
                .resizable()
                .scaledToFit()
                .foregroundStyle(darkBlue)
                .frame(width: size.width + 10, height: size.height + 10)

            // Light blue fill: constant-width rectangle + trapezoid shoulder above 80%
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if trapHeight > 0 {
                    TrapezoidShape(topWidth: neckWidth, bottomWidth: bodyWidth)
                        .fill(lightBlue)
                        .frame(width: bodyWidth, height: trapHeight)
                }
                Rectangle()
                    .fill(lightBlue)
                    .frame(width: bodyWidth, height: rectHeight)
            }
            .frame(width: bodyWidth, height: totalHeight)
            
            // Droplet overlay aligned with the waterbottle SF Symbol's embossed droplet
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(darkBlue)
                .frame(width: 13, height: 25)
                .offset(y: 4)
        }
        .animation(.easeInOut(duration: 0.4), value: fillFraction)
    }
}

#Preview {
    HStack(spacing: 24) {
        WaterBottleButton(fillFraction: 0.0)
        WaterBottleButton(fillFraction: 0.5)
        WaterBottleButton(fillFraction: 0.8)
        WaterBottleButton(fillFraction: 0.9)
        WaterBottleButton(fillFraction: 1.0)
    }
    .padding()
}
