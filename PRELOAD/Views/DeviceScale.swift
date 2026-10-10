import UIKit

/// Packages and shelf-label text are drawn at the game's iPhone-tuned reference sizes everywhere.
/// On iPad's much larger screen those same point sizes read as an afterthought, so this scale
/// factor is applied on top of them wherever a size is a flat constant rather than already
/// proportional to the truck's own geometry (which already scales with the screen via
/// `TruckLayout`).
enum DeviceScale {
    static let text: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.25 : 1.0
}
