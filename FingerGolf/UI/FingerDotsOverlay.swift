import UIKit
import Combine

class FingerDotsOverlay: UIView {

    var thumbPosition: CGPoint? { didSet { setNeedsDisplay() } }
    var indexPosition: CGPoint? { didSet { setNeedsDisplay() } }

    private let dotRadius: CGFloat = 14
    private let dotColor = UIColor.white.withAlphaComponent(0.45)
    private let dotBorderColor = UIColor.white.withAlphaComponent(0.7)
    private let dotBorderWidth: CGFloat = 2.0

    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isOpaque = false
    }

    func bind(to coordinator: HandTrackingCoordinator) {
        coordinator.$thumbScreenPosition
            .receive(on: RunLoop.main)
            .sink { [weak self] pos in
                self?.thumbPosition = pos
            }
            .store(in: &cancellables)

        coordinator.$indexScreenPosition
            .receive(on: RunLoop.main)
            .sink { [weak self] pos in
                self?.indexPosition = pos
            }
            .store(in: &cancellables)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        if let thumb = thumbPosition {
            drawDot(at: thumb, in: ctx, label: "T")
        }

        if let index = indexPosition {
            drawDot(at: index, in: ctx, label: "I")
        }

        // Draw connection line between dots if both visible
        if let thumb = thumbPosition, let index = indexPosition {
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: thumb)
            ctx.addLine(to: index)
            ctx.strokePath()
        }
    }

    private func drawDot(at point: CGPoint, in ctx: CGContext, label: String) {
        let dotRect = CGRect(
            x: point.x - dotRadius,
            y: point.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )

        // Fill
        ctx.setFillColor(dotColor.cgColor)
        ctx.fillEllipse(in: dotRect)

        // Border
        ctx.setStrokeColor(dotBorderColor.cgColor)
        ctx.setLineWidth(dotBorderWidth)
        ctx.strokeEllipse(in: dotRect)
    }
}
