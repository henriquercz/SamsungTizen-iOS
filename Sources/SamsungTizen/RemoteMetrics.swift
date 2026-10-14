import SwiftUI

public struct RemoteMetrics: Equatable {
    public let padDiameter: CGFloat
    public let centerButtonDiameter: CGFloat
    public let rockerWidth: CGFloat
    public let rockerHeight: CGFloat
    public let navButtonHeight: CGFloat
    public let touchTargetPadding: CGFloat

    public init(
        padDiameter: CGFloat = 220,
        centerButtonDiameter: CGFloat = 76,
        rockerWidth: CGFloat = 54,
        rockerHeight: CGFloat = 142,
        navButtonHeight: CGFloat = 46,
        touchTargetPadding: CGFloat = 12
    ) {
        self.padDiameter = padDiameter
        self.centerButtonDiameter = centerButtonDiameter
        self.rockerWidth = rockerWidth
        self.rockerHeight = rockerHeight
        self.navButtonHeight = navButtonHeight
        self.touchTargetPadding = touchTargetPadding
    }

    public static let mobile = RemoteMetrics(
        padDiameter: 220,
        centerButtonDiameter: 76,
        rockerWidth: 54,
        rockerHeight: 142,
        navButtonHeight: 46,
        touchTargetPadding: 12
    )
}
