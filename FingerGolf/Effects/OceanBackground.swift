import UIKit
import QuartzCore

class OceanBackground: UIView {

    private let gradientLayer = CAGradientLayer()
    private var displayLink: CADisplayLink?
    private var time: CGFloat = 0

    // Ocean palette
    private let topColors: [CGColor] = [
        UIColor(red: 0.45, green: 0.72, blue: 0.88, alpha: 1.0).cgColor,
        UIColor(red: 0.50, green: 0.75, blue: 0.90, alpha: 1.0).cgColor,
        UIColor(red: 0.48, green: 0.70, blue: 0.85, alpha: 1.0).cgColor,
    ]

    private let bottomColors: [CGColor] = [
        UIColor(red: 0.35, green: 0.58, blue: 0.78, alpha: 1.0).cgColor,
        UIColor(red: 0.30, green: 0.55, blue: 0.75, alpha: 1.0).cgColor,
        UIColor(red: 0.38, green: 0.60, blue: 0.80, alpha: 1.0).cgColor,
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false

        gradientLayer.colors = [topColors[0], bottomColors[0]]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func startAnimating() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        time += 0.008

        // Slow, gentle oscillation between color states
        let wave = (sin(time) + 1.0) / 2.0 // 0..1
        let colorIndex = Int(wave * CGFloat(topColors.count - 1))
        let nextIndex = min(colorIndex + 1, topColors.count - 1)
        let fraction = wave * CGFloat(topColors.count - 1) - CGFloat(colorIndex)

        let topColor = interpolateColor(topColors[colorIndex], topColors[nextIndex], fraction: fraction)
        let bottomColor = interpolateColor(bottomColors[colorIndex], bottomColors[nextIndex], fraction: fraction)

        // Animate gradient locations for wave-like motion
        let locationShift = sin(time * 0.7) * 0.08
        gradientLayer.locations = [
            NSNumber(value: 0.0 + locationShift),
            NSNumber(value: 1.0)
        ]
        gradientLayer.colors = [topColor, bottomColor]
    }

    private func interpolateColor(_ c1: CGColor, _ c2: CGColor, fraction: CGFloat) -> CGColor {
        guard let comp1 = c1.components, let comp2 = c2.components,
              comp1.count >= 3, comp2.count >= 3 else { return c1 }

        let f = min(max(fraction, 0), 1)
        let r = comp1[0] + (comp2[0] - comp1[0]) * f
        let g = comp1[1] + (comp2[1] - comp1[1]) * f
        let b = comp1[2] + (comp2[2] - comp1[2]) * f

        return UIColor(red: r, green: g, blue: b, alpha: 1.0).cgColor
    }

    deinit {
        stopAnimating()
    }
}
