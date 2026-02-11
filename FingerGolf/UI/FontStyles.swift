import SwiftUI

extension View {

    func titleStyle(size: CGFloat = 48) -> some View {
        self
            .font(.custom("Futura-Bold", size: size))
            .italic()
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 2, x: 1, y: 2)
    }

    func headingStyle(size: CGFloat = 22) -> some View {
        self
            .font(.custom("Futura-Bold", size: size))
            .italic()
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 1, x: 1, y: 1)
    }

    func bodyStyle(size: CGFloat = 16) -> some View {
        self
            .font(.custom("Futura-Bold", size: size))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0.5, y: 1)
    }

    func lightStyle(size: CGFloat = 14) -> some View {
        self
            .font(.custom("Futura-Medium", size: size))
            .foregroundStyle(.white.opacity(0.8))
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0.5, y: 1)
    }
}
