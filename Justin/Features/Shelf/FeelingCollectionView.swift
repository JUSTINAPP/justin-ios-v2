import SwiftUI

struct FeelingCollectionView: View {
    let feeling: ShelfFeeling
    @State private var selectedMessage: ShelfMessage?

    var body: some View {
        List {
            Section {
                Text("Each of these was made just for this moment.")
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                ForEach(feeling.messages) { message in
                    Button { selectedMessage = message } label: {
                        HStack(spacing: 14) {
                            InitialsAvatar(name: message.from, size: 44)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("From \(message.from)")
                                    .font(.system(.body).weight(.medium))
                                    .foregroundColor(.primary)
                                Text(message.duration)
                                    .font(.system(.caption))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.brandPurple)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Open when \(feeling.label)")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedMessage) { msg in
            KenBurnsPlayerView(
                voicePath: msg.shelfItem?.message.voiceUrl,
                photoPaths: msg.shelfItem?.message.photoUrls ?? [],
                fromName: msg.from
            )
        }
    }
}

#Preview {
    NavigationStack {
        FeelingCollectionView(feeling: ShelfFeeling(
            label: "you can't sleep",
            messages: [
                ShelfMessage(from: "Mum", duration: "0:42"),
                ShelfMessage(from: "Em", duration: "1:05"),
                ShelfMessage(from: "Dad", duration: "0:38"),
            ]
        ))
    }
}
