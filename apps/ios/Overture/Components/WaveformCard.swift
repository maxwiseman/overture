import SwiftUI

struct WaveformCard: View {
    @State private var isPlaying = false
    private let bars: [CGFloat] = [8, 12, 16, 10, 20, 14, 25, 18, 30, 42, 20, 36, 46, 31, 27, 44, 39, 25, 18, 12]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Only 75 perceived decibels")
                        .font(.headline)
                        .foregroundStyle(OvertureTheme.cobalt)
                    Text("Quieter than a running shower at ground level.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("75")
                        .font(.system(size: 38, weight: .light))
                    Text("dB")
                        .font(.subheadline)
                }
                .foregroundStyle(OvertureTheme.cobalt)
            }

            HStack(alignment: .center, spacing: 5) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(index > 8 ? OvertureTheme.cobalt : Color.secondary.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                }
            }
            .frame(height: 54)

            Button {
                withAnimation(.snappy) {
                    isPlaying.toggle()
                }
                Haptics.impact()
            } label: {
                Label(isPlaying ? "Playing the shaped boom" : "Listen to the shaped boom", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("waveform-play")
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 20))
        .padding(.vertical, 28)
    }
}
