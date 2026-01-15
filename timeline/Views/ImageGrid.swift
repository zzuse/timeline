import SwiftUI
import UIKit

struct ImageGrid: View {
    let images: [UIImage]
    var onRemove: ((Int) -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(images.indices, id: \.self) { index in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: images[index])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(8)

                    if let onRemove {
                        Button {
                            onRemove(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .padding(6)
                    }
                }
            }
        }
    }
}

#Preview {
    ImageGrid(images: [UIImage(systemName: "star")!])
        .padding()
}
