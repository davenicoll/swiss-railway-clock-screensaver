#!/usr/bin/env swift

import AppKit
import CoreGraphics

struct TimeState {
    let hours: Int
    let minutes: Int
    let seconds: Int
    let secondFraction: Double
    let isPaused: Bool
}

class ThumbnailRenderer {
    private let faceColor = NSColor.white
    private let markerColor = NSColor.black
    private let handColor = NSColor.black
    private let secondHandColor = NSColor(calibratedRed: 218.0/255.0, green: 41.0/255.0, blue: 28.0/255.0, alpha: 1.0)
    private let centerDotColor = NSColor.black

    func render(size: CGSize, timeState: TimeState) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        let rect = CGRect(origin: .zero, size: size)

        // Black background
        context.setFillColor(NSColor.black.cgColor)
        context.fill(rect)

        // Clock centered, with some padding
        let clockDiameter = min(size.width, size.height) * 0.85
        let radius = clockDiameter / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Clock face
        let faceRect = CGRect(x: center.x - radius, y: center.y - radius,
                              width: radius * 2, height: radius * 2)
        context.setFillColor(faceColor.cgColor)
        context.fillEllipse(in: faceRect)

        // Glass effect
        context.saveGState()
        context.addEllipse(in: faceRect)
        context.clip()
        let highlightCenter = CGPoint(x: center.x - radius * 0.3, y: center.y + radius * 0.3)
        let colors = [NSColor(white: 1.0, alpha: 0.15).cgColor, NSColor(white: 1.0, alpha: 0.0).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray, locations: [0.0, 1.0]) {
            context.drawRadialGradient(gradient, startCenter: highlightCenter, startRadius: 0,
                                       endCenter: highlightCenter, endRadius: radius * 0.9, options: [])
        }
        context.restoreGState()

        // Hour markers
        context.setFillColor(markerColor.cgColor)
        for hour in 0..<12 {
            let angle = .pi / 2 - CGFloat(hour) * (.pi / 6)
            let outerRadius = radius * 0.93
            let innerRadius = outerRadius - (radius * 0.14)
            let markerWidth = radius * 0.058

            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: angle)
            let markerRect = CGRect(x: innerRadius, y: -markerWidth / 2,
                                   width: outerRadius - innerRadius, height: markerWidth)
            context.fill(markerRect)
            context.restoreGState()
        }

        // Hour hand (10 hours + 10 minutes)
        let hourAngle = .pi / 2 - (CGFloat(timeState.hours) + CGFloat(timeState.minutes) / 60.0) * (.pi / 6)
        drawHand(context: context, center: center, radius: radius, angle: hourAngle,
                 length: 0.52, width: 0.07, tailLength: 0.14)

        // Minute hand (10 minutes)
        let minuteAngle = .pi / 2 - CGFloat(timeState.minutes) * (.pi / 30)
        drawHand(context: context, center: center, radius: radius, angle: minuteAngle,
                 length: 0.76, width: 0.055, tailLength: 0.16)

        // Second hand (30 seconds)
        let secondAngle = .pi / 2 - CGFloat(timeState.seconds) * (.pi / 30)
        let handLength = radius * 0.72
        let tailLength = radius * 0.20
        let ballRadius = radius * 0.065

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: secondAngle)
        context.setStrokeColor(secondHandColor.cgColor)
        context.setLineWidth(radius * 0.018)
        let ballCenterX = handLength - ballRadius
        context.move(to: CGPoint(x: -tailLength, y: 0))
        context.addLine(to: CGPoint(x: ballCenterX - ballRadius * 0.3, y: 0))
        context.strokePath()
        context.setFillColor(secondHandColor.cgColor)
        context.fillEllipse(in: CGRect(x: ballCenterX - ballRadius, y: -ballRadius,
                                       width: ballRadius * 2, height: ballRadius * 2))
        context.restoreGState()

        // Center cap
        let capRadius = radius * 0.035
        context.setFillColor(centerDotColor.cgColor)
        context.fillEllipse(in: CGRect(x: center.x - capRadius, y: center.y - capRadius,
                                       width: capRadius * 2, height: capRadius * 2))

        image.unlockFocus()
        return image
    }

    private func drawHand(context: CGContext, center: CGPoint, radius: CGFloat,
                          angle: CGFloat, length: CGFloat, width: CGFloat, tailLength: CGFloat) {
        let handLength = radius * length
        let handWidth = radius * width
        let tail = radius * tailLength
        let halfWidth = handWidth / 2

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angle)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -tail, y: halfWidth))
        path.addLine(to: CGPoint(x: -tail, y: -halfWidth))
        path.addLine(to: CGPoint(x: handLength - halfWidth, y: -halfWidth))
        path.addArc(center: CGPoint(x: handLength - halfWidth, y: 0), radius: halfWidth,
                    startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        path.addLine(to: CGPoint(x: -tail, y: halfWidth))
        path.closeSubpath()

        context.setFillColor(handColor.cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }
}

// Generate 267x162 thumbnail at 10:10:30
let renderer = ThumbnailRenderer()
let timeState = TimeState(hours: 10, minutes: 10, seconds: 30, secondFraction: 0, isPaused: false)
let size = CGSize(width: 267, height: 162)

if let image = renderer.render(size: size, timeState: timeState) {
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "/Users/dave/gt/SwissRailwayClock/SwissRailwayClock/thumbnail.png")
        try? pngData.write(to: url)
        print("Generated thumbnail.png (267x162)")
    }
}
