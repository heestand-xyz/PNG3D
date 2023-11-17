import SwiftUI

public struct FlexView<Content: View>: View {
    
    let contentMode: ContentMode

    let content: () -> Content
    
    public init(contentMode: ContentMode,
                @ViewBuilder content: @escaping () -> Content) {
        
        self.contentMode = contentMode
        
        self.content = content
    }
    
    @State var size: CGSize?
    
    private var aspectRatio: CGFloat {
        guard let size
        else { return 1.0 }
        return size.width / size.height
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                content()
                    .read(size: $size)
                    .aspectRatio(aspectRatio, contentMode: contentMode)
                    .offset({
                        
                        guard contentMode == .fill
                        else { return .zero }
                        
                        let size: CGSize = geometry.size
                        let _aspectRatio = size.width / size.height
                        
                        let x: CGFloat = {
                            if aspectRatio > _aspectRatio {
                                return -(size.width * (aspectRatio / _aspectRatio) - size.width) / 2
                            }
                            return 0.0
                        }()
                        
                        let y: CGFloat = {
                            if aspectRatio < _aspectRatio {
                                return -(size.height * (_aspectRatio / aspectRatio) - size.height) / 2
                            }
                            return 0.0
                        }()
                        
                        return CGSize(width: x, height: y)
                    }())
            }
        }
        .clipped()
    }
}
