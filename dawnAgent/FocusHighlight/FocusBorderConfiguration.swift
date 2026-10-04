import AppKit

struct FocusBorderConfiguration: Equatable {
    var isEnabled: Bool
    var borderWidth: CGFloat
    var borderColor: NSColor
    var cornerRadius: CGFloat

    static let `default` = FocusBorderConfiguration(
        isEnabled: true,
        borderWidth: 2,
        borderColor: .systemBlue.withAlphaComponent(0.5),
        cornerRadius: 12
    )
}
