import PixlPlatform
import Swift

public extension Color {
    // MARK: Accent colors

    static let red = Self(red: 1, green: 0.25882353, blue: 0.27058825)
    static let orange = Self(red: 1, green: 0.57254905, blue: 0.1882353)
    static let yellow = Self(red: 1, green: 0.8392157, blue: 0)
    static let green = Self(red: 0.1882353, green: 0.81960785, blue: 0.34509805)
    static let mint = Self(red: 0, green: 0.85490197, blue: 0.7647059)
    static let teal = Self(red: 0, green: 0.8235294, blue: 0.8784314)
    static let cyan = Self(red: 0.23529412, green: 0.827451, blue: 0.99607843)
    static let blue = Self(red: 0, green: 0.5686275, blue: 1)
    static let indigo = Self(red: 0.427451, green: 0.4862745, blue: 1)
    static let purple = Self(red: 0.85882354, green: 0.20392157, blue: 0.9490196)
    static let pink = Self(red: 1, green: 0.21568628, blue: 0.37254903)
    static let brown = Self(red: 0.7176471, green: 0.5411765, blue: 0.4)

    // MARK: Greys

    static let gray = Self(red: 0.5568628, green: 0.5568628, blue: 0.5764706)
    static let gray2 = Self(red: 0.3882353, green: 0.3882353, blue: 0.4)
    static let gray3 = Self(red: 0.28235295, green: 0.28235295, blue: 0.2901961)
    static let gray4 = Self(red: 0.22745098, green: 0.22745098, blue: 0.23529412)
    static let gray5 = Self(red: 0.17254902, green: 0.17254902, blue: 0.18039216)
    static let gray6 = Self(red: 0.10980392, green: 0.10980392, blue: 0.11764706)

    // MARK: Text

    static let primary = Self.white
    static let secondary = Self(red: 0.92156863, green: 0.92156863, blue: 0.9607843, alpha: 0.6)
    static let tertiary = Self(red: 0.92156863, green: 0.92156863, blue: 0.9607843, alpha: 0.29803923)
    static let quaternary = Self(red: 0.92156863, green: 0.92156863, blue: 0.9607843, alpha: 0.15686275)
    static let placeholder = Self(red: 0.92156863, green: 0.92156863, blue: 0.9607843, alpha: 0.29803923)

    // MARK: Overlay fills

    static let fill = Self(red: 0.47058824, green: 0.47058824, blue: 0.5019608, alpha: 0.36078432)
    static let secondaryFill = Self(red: 0.47058824, green: 0.47058824, blue: 0.5019608, alpha: 0.32156864)
    static let tertiaryFill = Self(red: 0.4627451, green: 0.4627451, blue: 0.5019608, alpha: 0.23921569)
    static let quaternaryFill = Self(red: 0.4627451, green: 0.4627451, blue: 0.5019608, alpha: 0.18039216)

    // MARK: Surfaces

    static let background = Self.black
    static let secondaryBackground = Self(red: 0.10980392, green: 0.10980392, blue: 0.11764706)
    static let tertiaryBackground = Self(red: 0.17254902, green: 0.17254902, blue: 0.18039216)

    // MARK: Lines and links

    static let separator = Self(red: 0.32941177, green: 0.32941177, blue: 0.34509805, alpha: 0.5)
    static let opaqueSeparator = Self(red: 0.21960784, green: 0.21960784, blue: 0.22745098)
    static let link = Self(red: 0.03529412, green: 0.5176471, blue: 1)
}
