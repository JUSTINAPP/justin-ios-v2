import SwiftUI

struct GivingView: View {
    @State private var showRecord = false

    private let gifts: [(name: String, subtitle: String, icon: String)] = [
        ("Em",     "4 messages",                    "heart"),
        ("Mum",    "opened 2 days ago",              "checkmark.circle"),
        ("Jordan", "opens first day at uni",         "calendar"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // Cream world background
            Color.cream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    Text("Giving")
                        .font(.system(.title2).weight(.semibold))
                        .foregroundColor(.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    ForEach(gifts, id: \.name) { gift in
                        NavigationLink(destination: GiftDetailView(recipientName: gift.name)) {
                            giftCard(gift)
                        }
                        .buttonStyle(.plain)
                    }

                    // "Start a gift" card — secondary entry point
                    Button { showRecord = true } label: {
                        startGiftCard
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // clear the floating button
            }

            // Floating + — ONLY on the Giving tab, bottom-center, above tab bar
            Button { showRecord = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.ink)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Giving")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView()
        }
    }

    private func giftCard(_ gift: (name: String, subtitle: String, icon: String)) -> some View {
        HStack(spacing: 14) {
            InitialsAvatar(name: gift.name, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("For \(gift.name)")
                    .font(.system(.body).weight(.medium))
                    .foregroundColor(.ink)
                Text(gift.subtitle)
                    .font(.system(.subheadline))
                    .foregroundColor(Color.ink.opacity(0.5))
            }
            Spacer()
            Image(systemName: gift.icon)
                .foregroundColor(.brandPurple)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    private var startGiftCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.brandPurple)
            Text("Start a gift for someone")
                .font(.system(.body).weight(.medium))
                .foregroundColor(.brandPurple)
            Spacer()
        }
        .padding(16)
        .background(Color.brandPurple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.brandPurple.opacity(0.22), lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack { GivingView() }
}
