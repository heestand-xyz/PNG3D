# PNG3D

File Format for 3D Images

The format is a zip file with a custom extension "png3d", this is a folder of a `info.json` file and a `layers` folder with png images.

## Example

```swift
let resolution = SIMD3<Int>(100, 100, 100)
let graphic3D: Graphic3D = try await .sphere(resolution: resolution)
let fileData = try await PNG3D.write(graphic3D)
let fileURL = URL(filePath: "/Users/.../Desktop/test.png3d")
try fileData.write(to: fileURL)
```
