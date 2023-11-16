# PNG3D

A file format for voxel images.
                    
```swift
let resolution = SIMD3<Int>(100, 100, 100)
let graphic3D: Graphic3D = try await .sphere(resolution: resolution)
let fileData = try await PNG3D.write(graphic3D)
let fileURL = URL(filePath: "/Users/.../Desktop/test.png3d")
try fileData.write(to: fileURL)
```
