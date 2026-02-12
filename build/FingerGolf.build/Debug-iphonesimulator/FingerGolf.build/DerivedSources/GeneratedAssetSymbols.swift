import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "GameUI" asset catalog resource namespace.
    enum GameUI {

        /// The "GameUI/arrow_basic_e" asset catalog image resource.
        static let arrowBasicE = DeveloperToolsSupport.ImageResource(name: "GameUI/arrow_basic_e", bundle: resourceBundle)

        /// The "GameUI/arrow_basic_n" asset catalog image resource.
        static let arrowBasicN = DeveloperToolsSupport.ImageResource(name: "GameUI/arrow_basic_n", bundle: resourceBundle)

        /// The "GameUI/arrow_basic_s" asset catalog image resource.
        static let arrowBasicS = DeveloperToolsSupport.ImageResource(name: "GameUI/arrow_basic_s", bundle: resourceBundle)

        /// The "GameUI/arrow_basic_w" asset catalog image resource.
        static let arrowBasicW = DeveloperToolsSupport.ImageResource(name: "GameUI/arrow_basic_w", bundle: resourceBundle)

        /// The "GameUI/button_rectangle_depth_flat" asset catalog image resource.
        static let buttonRectangleDepthFlat = DeveloperToolsSupport.ImageResource(name: "GameUI/button_rectangle_depth_flat", bundle: resourceBundle)

        /// The "GameUI/button_rectangle_depth_gradient" asset catalog image resource.
        static let buttonRectangleDepthGradient = DeveloperToolsSupport.ImageResource(name: "GameUI/button_rectangle_depth_gradient", bundle: resourceBundle)

        /// The "GameUI/button_round_depth_flat" asset catalog image resource.
        static let buttonRoundDepthFlat = DeveloperToolsSupport.ImageResource(name: "GameUI/button_round_depth_flat", bundle: resourceBundle)

        /// The "GameUI/icon_checkmark" asset catalog image resource.
        static let iconCheckmark = DeveloperToolsSupport.ImageResource(name: "GameUI/icon_checkmark", bundle: resourceBundle)

        /// The "GameUI/icon_cross" asset catalog image resource.
        static let iconCross = DeveloperToolsSupport.ImageResource(name: "GameUI/icon_cross", bundle: resourceBundle)

        /// The "GameUI/star" asset catalog image resource.
        static let star = DeveloperToolsSupport.ImageResource(name: "GameUI/star", bundle: resourceBundle)

        /// The "GameUI/star_outline" asset catalog image resource.
        static let starOutline = DeveloperToolsSupport.ImageResource(name: "GameUI/star_outline", bundle: resourceBundle)

    }

    /// The "club-green" asset catalog image resource.
    static let clubGreen = DeveloperToolsSupport.ImageResource(name: "club-green", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "GameUI" asset catalog resource namespace.
    enum GameUI {

        /// The "GameUI/arrow_basic_e" asset catalog image.
        static var arrowBasicE: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.arrowBasicE)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_n" asset catalog image.
        static var arrowBasicN: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.arrowBasicN)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_s" asset catalog image.
        static var arrowBasicS: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.arrowBasicS)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_w" asset catalog image.
        static var arrowBasicW: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.arrowBasicW)
#else
            .init()
#endif
        }

        /// The "GameUI/button_rectangle_depth_flat" asset catalog image.
        static var buttonRectangleDepthFlat: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.buttonRectangleDepthFlat)
#else
            .init()
#endif
        }

        /// The "GameUI/button_rectangle_depth_gradient" asset catalog image.
        static var buttonRectangleDepthGradient: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.buttonRectangleDepthGradient)
#else
            .init()
#endif
        }

        /// The "GameUI/button_round_depth_flat" asset catalog image.
        static var buttonRoundDepthFlat: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.buttonRoundDepthFlat)
#else
            .init()
#endif
        }

        /// The "GameUI/icon_checkmark" asset catalog image.
        static var iconCheckmark: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.iconCheckmark)
#else
            .init()
#endif
        }

        /// The "GameUI/icon_cross" asset catalog image.
        static var iconCross: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.iconCross)
#else
            .init()
#endif
        }

        /// The "GameUI/star" asset catalog image.
        static var star: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.star)
#else
            .init()
#endif
        }

        /// The "GameUI/star_outline" asset catalog image.
        static var starOutline: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
            .init(resource: .GameUI.starOutline)
#else
            .init()
#endif
        }

    }

    /// The "club-green" asset catalog image.
    static var clubGreen: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .clubGreen)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "GameUI" asset catalog resource namespace.
    enum GameUI {

        /// The "GameUI/arrow_basic_e" asset catalog image.
        static var arrowBasicE: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.arrowBasicE)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_n" asset catalog image.
        static var arrowBasicN: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.arrowBasicN)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_s" asset catalog image.
        static var arrowBasicS: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.arrowBasicS)
#else
            .init()
#endif
        }

        /// The "GameUI/arrow_basic_w" asset catalog image.
        static var arrowBasicW: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.arrowBasicW)
#else
            .init()
#endif
        }

        /// The "GameUI/button_rectangle_depth_flat" asset catalog image.
        static var buttonRectangleDepthFlat: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.buttonRectangleDepthFlat)
#else
            .init()
#endif
        }

        /// The "GameUI/button_rectangle_depth_gradient" asset catalog image.
        static var buttonRectangleDepthGradient: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.buttonRectangleDepthGradient)
#else
            .init()
#endif
        }

        /// The "GameUI/button_round_depth_flat" asset catalog image.
        static var buttonRoundDepthFlat: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.buttonRoundDepthFlat)
#else
            .init()
#endif
        }

        /// The "GameUI/icon_checkmark" asset catalog image.
        static var iconCheckmark: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.iconCheckmark)
#else
            .init()
#endif
        }

        /// The "GameUI/icon_cross" asset catalog image.
        static var iconCross: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.iconCross)
#else
            .init()
#endif
        }

        /// The "GameUI/star" asset catalog image.
        static var star: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.star)
#else
            .init()
#endif
        }

        /// The "GameUI/star_outline" asset catalog image.
        static var starOutline: UIKit.UIImage {
#if !os(watchOS)
            .init(resource: .GameUI.starOutline)
#else
            .init()
#endif
        }

    }

    /// The "club-green" asset catalog image.
    static var clubGreen: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .clubGreen)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

