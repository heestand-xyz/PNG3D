# PNG3D

File Format for 3D Images

## Example

```swift
let resolution = SIMD3<Int>(100, 100, 100)
let graphic3D: Graphic3D = try await .sphere(resolution: resolution)
let fileData: Data = try await PNG3D.write(graphic3D: graphic3D)
let fileURL = URL(filePath: "/Users/.../Desktop/test.png3d")
try fileData.write(to: fileURL)
```
