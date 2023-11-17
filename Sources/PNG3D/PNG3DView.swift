import SwiftUI
import AsyncGraphics

public struct PNG3DView<Placeholder: View>: View {
    
    public enum PlaceholderReason {
        case loading
        case failed(LoadError)
    }
    
    public enum LoadError: Error {
        case fileNotFound
        case fileLoadFailed(Error)
    }
    
    private let url: URL?
    
    private let placement: PNG3DPlacement
    private let placeholder: (PlaceholderReason) -> Placeholder
    
    public init(named name: String, 
                in bundle: Bundle = .main,
                placement: PNG3DPlacement = .fixed,
                placeholder: @escaping (PlaceholderReason) -> Placeholder = { _ in EmptyView() }) {
        if let url = bundle.url(forResource: name, withExtension: PNG3D.fileExtension) {
            self.init(url: url, placement: placement, placeholder: placeholder)
        } else {
            self.init(loadError: .fileNotFound, placement: placement, placeholder: placeholder)
        }
    }
    
    public init(url: URL,
                placement: PNG3DPlacement = .fixed,
                placeholder: @escaping (PlaceholderReason) -> Placeholder = { _ in EmptyView() }) {
        self.url = url
        self.placement = placement
        self.placeholder = placeholder
    }
    
    private init(loadError: LoadError,
                 placement: PNG3DPlacement,
                 placeholder: @escaping (PlaceholderReason) -> Placeholder) {
        url = nil
        self.placement = placement
        self.placeholder = placeholder
        self.loadError = loadError
    }
    
    @State private var graphic3D: Graphic3D?
    @State private var loadError: LoadError?
    
    public var body: some View {
        ZStack {
            if let graphic3D: Graphic3D {
                switch placement {
                case .fixed:
                    Graphic3DView(graphic3D: graphic3D)
                        .frame(width: CGFloat(graphic3D.width),
                               height: CGFloat(graphic3D.height))
                case .fit:
                    Graphic3DView(graphic3D: graphic3D)
                case .fill:
                    FlexView(contentMode: .fill) {
                        Graphic3DView(graphic3D: graphic3D)
                    }
                }
            } else if let loadError: LoadError {
                placeholder(.failed(loadError))
            } else {
                placeholder(.loading)
            }
        }
        .task {
            guard let url: URL else { return }
            do {
                graphic3D = try await PNG3D.read(url: url)
            } catch {
                loadError = .fileLoadFailed(error)
            }
        }
    }
}
