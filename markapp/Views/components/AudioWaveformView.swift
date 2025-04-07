import SwiftUI

struct AudioWaveformView: View {
    let levels: [CGFloat]
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 30 * levels[index])
            }
        }
        .animation(.linear(duration: 0.05), value: levels)
    }
}

struct AudioWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        AudioWaveformView(
            levels: [0.2, 0.5, 0.8, 0.4, 0.6, 0.3, 0.9, 0.7, 0.5, 0.3, 0.2, 0.5, 0.3, 0.6, 0.5, 0.7, 0.4, 0.2, 0.3, 0.5, 0.3, 0.5, 0.7, 0.6, 0.4, 0.2, 0.3, 0.5, 0.6, 0.8],
            color: .blue
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 