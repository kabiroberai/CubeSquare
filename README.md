# CubeSquare

Your one stop shop for twisty puzzles on Apple platforms.

See [this tweet](https://x.com/kabiroberai/status/1902151939497873548) for a live demo!

![Screenshot](Assets/Screenshot.png?raw=true "Screenshot")

## About

CubeSquare is currently primarily built for visionOS and smart cubes like the [Gan12 UI Freeplay](https://www.gancube.com/products/gan12-ui-freeplay-3x3-flagship-speed-cube). Improved support for other platforms and (non-smart / smart) cubes may or may not come in the future.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen)
2. Clone this repo
3. To codesign for a real device, create `CubeSquare/Config/Private.xcconfig` with the contents `DEVELOPMENT_TEAM = YOUR_TEAM` (where `YOUR_TEAM` is your development team ID.)
4. Run `make` to generate and open the Xcode project.

After this, you can build and run the Xcode project as usual.

## Thanks

This project would not have been possible without several amazing resources:

- [Socratica](https://www.socratica.info), a wonderful coworking collective at the University of Waterloo where I built much of this project
- Herbert Kociemba's [Two-Phase Algorithm](https://kociemba.org/cube.htm) for solving the Rubik's Cube.
- Maxim Tsoy's [C port](https://github.com/muodov/kociemba) of Kociemba's algorithm.
- Javi Soto's [RubikSwift](https://github.com/JaviSoto/RubikSwift) package that served as a starting point for CubeKit.
- Andy Fedotov's [gan-web-bluetooth](https://github.com/afedotov/gan-web-bluetooth) which was the basis of the CoreBluetooth code for interacting with GAN cubes.
- Ludovic Fernandez's [cube.js](https://github.com/ldez/cubejs) which was helpful for understanding the more intricate aspects of modelling the cube, such as generating uniform scrambles.
