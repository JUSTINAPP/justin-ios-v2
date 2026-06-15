import SwiftUI

struct ShelfView: View {
    @State private var showPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Ready for you now
                sectionHeader("Ready for you now")
                Button { showPlayer = true } label: {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.brandPurple, .brandRose],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("From Mum")
                                .font(.system(.headline).weight(.semibold))
                                .foregroundColor(.white)
                            Text("just arrived")
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(16)
                    }
                }
                .buttonStyle(.plain)

                // MARK: Open when…
                sectionHeader("Open when\u{2026}")
                VStack(spacing: 0) {
                    ForEach(["you can't sleep", "you miss home"], id: \.self) { feeling in
                        HStack {
                            Text("Open when \(feeling)")
                                .font(.system(.body))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                        Divider()
                    }
                }

                // MARK: Always here
                sectionHeader("Always here")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("For your hardest moments")
                            .font(.system(.subheadline).weight(.medium))
                            .foregroundColor(.white)
                        Text("From Em")
                            .font(.system(.caption))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "heart.fill")
                        .foregroundColor(.brandRose)
                }
                .padding(16)
                .background(Color.brandDeep)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // MARK: Arriving later
                sectionHeader("Arriving later")
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From Dad")
                            .font(.system(.body))
                        Text("opens on your birthday")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .opacity(0.55)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Your shelf")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showPlayer) {
            KenBurnsPlayerView()
                .overlay(alignment: .topLeading) {
                    Button { showPlayer = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(11)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.leading, 20)
                }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .default).weight(.semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}

#Preview {
    NavigationStack { ShelfView() }
}
