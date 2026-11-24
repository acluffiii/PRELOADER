import SwiftUI

/// The poster / app-icon palette: sky blue, cardboard brown, and the same orange the
/// shift-start and menu buttons already use (`Color.orange` / system orange). In-round art
/// reads from here so the loader, boxes, and van stay in one family.
enum ArtPalette {
    static let orange = Color.orange

    static let skyTop = Color(red: 0.47, green: 0.73, blue: 0.88)
    static let sky = Color(red: 0.380, green: 0.627, blue: 0.792) // poster field, #61A0CA
    static let skyDeep = Color(red: 0.18, green: 0.30, blue: 0.40)

    static let boxTop = Color(red: 0.871, green: 0.678, blue: 0.322) // #DEAD52
    static let boxFront = Color(red: 0.820, green: 0.596, blue: 0.224) // #D19839
    static let boxFrontShade = Color(red: 0.70, green: 0.48, blue: 0.16)
    static let boxSide = Color(red: 0.659, green: 0.459, blue: 0.153) // #A87527
    static let tape = Color(red: 0.93, green: 0.84, blue: 0.64)
    static let airTape = Color(red: 0.55, green: 0.78, blue: 0.90)

    static let skin = Color(red: 0.478, green: 0.298, blue: 0.184) // #7A4C2F
    static let skinLight = Color(red: 0.608, green: 0.455, blue: 0.357) // #9B745B
    static let skinShade = Color(red: 0.322, green: 0.196, blue: 0.122)
    static let cap = Color(red: 0.353, green: 0.247, blue: 0.145) // #5A3F25
    static let capLight = Color(red: 0.510, green: 0.420, blue: 0.341) // #826B57
    static let capShade = Color(red: 0.227, green: 0.153, blue: 0.082)
    static let shirt = Color(red: 0.514, green: 0.322, blue: 0.204) // #835234
    static let shirtLight = Color(red: 0.64, green: 0.42, blue: 0.27)
    static let shirtShade = Color(red: 0.322, green: 0.224, blue: 0.129) // #523921
    static let pants = Color(red: 0.275, green: 0.188, blue: 0.110) // #46301C
    static let pantsShade = Color(red: 0.16, green: 0.11, blue: 0.07)
    static let shoe = Color(red: 0.10, green: 0.08, blue: 0.06)
    static let hair = Color(red: 0.110, green: 0.082, blue: 0.051) // #1C150D
    static let collar = Color(red: 0.91, green: 0.88, blue: 0.83)

    static let vanWhite = Color(red: 0.941, green: 0.941, blue: 0.922) // #F0F0EB
    static let vanShade = Color(red: 0.831, green: 0.831, blue: 0.808) // #D4D4CE
    static let steel = Color(red: 0.165, green: 0.220, blue: 0.275)
    static let steelLight = Color(red: 0.55, green: 0.64, blue: 0.70)
}
