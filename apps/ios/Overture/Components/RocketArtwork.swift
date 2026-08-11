import SwiftUI

struct RocketArtwork: View {
    let vehicle: String

    var body: some View {
        Canvas { context, size in
            let kind = RocketKind(vehicle: vehicle)
            let scale = min(size.width / 180, size.height / 360)
            let rocketSize = CGSize(width: 180 * scale, height: 360 * scale)
            let origin = CGPoint(
                x: (size.width - rocketSize.width) / 2,
                y: size.height - rocketSize.height
            )

            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: scale, y: scale)
            drawRocket(kind, in: &context)
        }
        .accessibilityHidden(true)
    }

    private func drawRocket(_ kind: RocketKind, in context: inout GraphicsContext) {
        let bodyWidth = kind.bodyWidth
        let left = 90 - bodyWidth / 2
        let right = 90 + bodyWidth / 2
        let noseBottom = kind.noseBottom
        let bodyBottom: CGFloat = 305

        let glow = Path(ellipseIn: CGRect(x: 42, y: 326, width: 96, height: 22))
        context.fill(glow, with: .color(.white.opacity(0.10)))

        if kind == .sls {
            drawBooster(x: left - 21, in: &context)
            drawBooster(x: right + 7, in: &context)
        }

        var nose = Path()
        nose.move(to: CGPoint(x: left, y: noseBottom))
        nose.addCurve(
            to: CGPoint(x: 90, y: 18),
            control1: CGPoint(x: left + 2, y: 66),
            control2: CGPoint(x: 76, y: 25)
        )
        nose.addCurve(
            to: CGPoint(x: right, y: noseBottom),
            control1: CGPoint(x: 104, y: 25),
            control2: CGPoint(x: right - 2, y: 66)
        )
        nose.closeSubpath()
        context.fill(nose, with: .linearGradient(
            Gradient(colors: [.white, Color(white: 0.70), .white]),
            startPoint: CGPoint(x: left, y: 0),
            endPoint: CGPoint(x: right, y: 0)
        ))

        let body = Path(roundedRect: CGRect(
            x: left,
            y: noseBottom - 1,
            width: bodyWidth,
            height: bodyBottom - noseBottom + 1
        ), cornerRadius: kind == .electron ? 3 : 6)
        context.fill(body, with: .linearGradient(
            Gradient(colors: [Color(white: 0.93), Color(white: 0.56), Color(white: 0.96)]),
            startPoint: CGPoint(x: left, y: 0),
            endPoint: CGPoint(x: right, y: 0)
        ))

        if let bodyColor = kind.bodyColor {
            let coloredBody = Path(roundedRect: CGRect(
                x: left + 3,
                y: noseBottom + 20,
                width: bodyWidth - 6,
                height: bodyBottom - noseBottom - 28
            ), cornerRadius: 3)
            context.fill(coloredBody, with: .color(bodyColor))
        }

        let darkBandHeight = kind == .starship ? 24.0 : 43.0
        let darkBand = Path(roundedRect: CGRect(
            x: left,
            y: bodyBottom - darkBandHeight,
            width: bodyWidth,
            height: darkBandHeight
        ), cornerRadius: 3)
        context.fill(darkBand, with: .color(Color(white: 0.12)))

        var leftFin = Path()
        leftFin.move(to: CGPoint(x: left + 4, y: 266))
        leftFin.addLine(to: CGPoint(x: left - kind.finWidth, y: 322))
        leftFin.addLine(to: CGPoint(x: left + 7, y: 307))
        leftFin.closeSubpath()
        context.fill(leftFin, with: .color(Color(white: 0.27)))

        var rightFin = Path()
        rightFin.move(to: CGPoint(x: right - 4, y: 266))
        rightFin.addLine(to: CGPoint(x: right + kind.finWidth, y: 322))
        rightFin.addLine(to: CGPoint(x: right - 7, y: 307))
        rightFin.closeSubpath()
        context.fill(rightFin, with: .color(Color(white: 0.18)))

        let engine = Path(roundedRect: CGRect(
            x: 90 - bodyWidth * 0.31,
            y: bodyBottom - 1,
            width: bodyWidth * 0.62,
            height: 17
        ), cornerRadius: 3)
        context.fill(engine, with: .color(Color(white: 0.10)))

        if kind == .starship {
            let window = Path(ellipseIn: CGRect(x: 84, y: 48, width: 12, height: 6))
            context.fill(window, with: .color(Color(white: 0.12)))
        }

        for y in kind.detailBands {
            var line = Path()
            line.move(to: CGPoint(x: left + 2, y: y))
            line.addLine(to: CGPoint(x: right - 2, y: y))
            context.stroke(line, with: .color(.black.opacity(0.24)), lineWidth: 1)
        }
    }

    private func drawBooster(x: CGFloat, in context: inout GraphicsContext) {
        let booster = Path(roundedRect: CGRect(x: x, y: 110, width: 14, height: 203), cornerRadius: 7)
        context.fill(booster, with: .linearGradient(
            Gradient(colors: [.white, Color(white: 0.58), .white]),
            startPoint: CGPoint(x: x, y: 0),
            endPoint: CGPoint(x: x + 14, y: 0)
        ))

        let cap = Path(ellipseIn: CGRect(x: x, y: 103, width: 14, height: 18))
        context.fill(cap, with: .color(.white))
    }
}

private enum RocketKind: Equatable {
    case falcon
    case starship
    case sls
    case electron
    case vulcan
    case generic

    init(vehicle: String) {
        let name = vehicle.lowercased()
        if name.contains("starship") || name.contains("super heavy") {
            self = .starship
        } else if name.contains("falcon") {
            self = .falcon
        } else if name.contains("sls") || name.contains("space launch system") {
            self = .sls
        } else if name.contains("electron") {
            self = .electron
        } else if name.contains("vulcan") || name.contains("atlas") {
            self = .vulcan
        } else {
            self = .generic
        }
    }

    var bodyWidth: CGFloat {
        switch self {
        case .starship: 58
        case .sls: 44
        case .electron: 28
        case .vulcan: 43
        case .falcon, .generic: 38
        }
    }

    var noseBottom: CGFloat {
        switch self {
        case .starship: 104
        case .electron: 82
        default: 96
        }
    }

    var finWidth: CGFloat {
        switch self {
        case .starship: 23
        case .electron: 11
        default: 17
        }
    }

    var bodyColor: Color? {
        switch self {
        case .sls: Color(red: 0.78, green: 0.32, blue: 0.10)
        case .electron: Color(white: 0.11)
        default: nil
        }
    }

    var detailBands: [CGFloat] {
        switch self {
        case .starship: [146, 242]
        case .sls: [124, 210]
        case .electron: [118, 194, 249]
        case .vulcan: [129, 234]
        case .falcon, .generic: [116, 226]
        }
    }
}

#Preview {
    HStack {
        RocketArtwork(vehicle: "Falcon 9")
        RocketArtwork(vehicle: "Starship Super Heavy")
        RocketArtwork(vehicle: "SLS Block 1B")
    }
    .frame(height: 360)
    .padding()
    .background(OvertureTheme.ink)
}
