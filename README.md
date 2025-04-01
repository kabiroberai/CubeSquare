# CubeSquare

Your one stop shop for twisty puzzles on Apple platforms.

See [this tweet](https://x.com/kabiroberai/status/1902151939497873548) for a live demo!

## About

CubeSquare is currently primarily built for visionOS and smart cubes like the [Gan12 UI Freeplay](https://www.gancube.com/products/gan12-ui-freeplay-3x3-flagship-speed-cube). Improved support for other platforms and (non-smart / smart) cubes may or may not come in the future.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2. Clone this repo
3. To codesign for a real device, create `CubeSquare/Config/Private.xcconfig` with the contents `DEVELOPMENT_TEAM = YOUR_TEAM` (where `YOUR_TEAM` is your development team ID.)
4. Run `make` to generate and open the Xcode project.

After this, you can build and run the Xcode project as usual.
