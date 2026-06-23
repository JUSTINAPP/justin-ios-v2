import SwiftUI
import PhotosUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var showSignOutConfirm = false

    // Avatar
    @State private var pickerItem: PhotosPickerItem?
    @State private var avatarData: Data?          // local preview after picking
    @State private var avatarSignedURL: URL?       // loaded from storage on appear
    @State private var isSavingAvatar = false

    var body: some View {
        List {
            Section {
                Text("Profile")
                    .font(.system(.title2).weight(.semibold))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)

            // Profile header
            Section {
                HStack(spacing: 14) {
                    avatarPicker
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.currentPerson?.displayName ?? "You")
                            .font(.title3.weight(.semibold))
                        if let phone = auth.currentPerson?.phone {
                            Text(phone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Settings rows
            Section {
                NavigationLink(destination: AccountView()) {
                    Text("Account")
                }
                NavigationLink(destination: NotificationsView()) {
                    Text("Notifications")
                }
                NavigationLink(destination: SafetyPrivacyView()) {
                    Text("Safety & privacy")
                }
            }

            // Sign out — destructive, confirmation required
            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Text("Sign out")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need your phone number to sign back in.")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(item) }
        }
        .task {
            guard let path = auth.currentPerson?.avatarUrl else { return }
            avatarSignedURL = try? await supabase.storage
                .from("photos")
                .createSignedURL(path: path, expiresIn: 3600)
        }
    }

    // MARK: - Avatar picker

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                PersonAvatarView(
                    name: auth.currentPerson?.displayName ?? "You",
                    size: 60,
                    localPhotoData: avatarData,
                    remoteAvatarURL: avatarSignedURL
                )
                .overlay {
                    if isSavingAvatar {
                        Circle()
                            .fill(.black.opacity(0.4))
                        ProgressView()
                            .tint(.white)
                    }
                }
                .clipShape(Circle())

                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, Color.brandPurple)
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .disabled(isSavingAvatar)
    }

    // MARK: - Upload

    private func uploadAvatar(_ item: PhotosPickerItem) async {
        guard let currentId = auth.currentPerson?.id else {
            debugLog("[Profile] FAILED — no currentPerson id")
            return
        }
        guard let rawData = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: rawData),
              let jpegData = compressedAvatarData(from: uiImage) else {
            debugLog("[Profile] FAILED — could not load/compress image data")
            return
        }
        debugLog("[Profile] image: \(rawData.count / 1024) KB raw → \(jpegData.count / 1024) KB compressed")

        isSavingAvatar = true
        defer { isSavingAvatar = false }

        let uploadId = UUID().uuidString
        let path = "avatars/\(currentId)/\(uploadId).jpg"

        debugLog("[Profile] WRITE — uploading to photos/\(path)  size=\(jpegData.count) bytes")
        debugLog("[Profile] READ  ← people.avatar_url (display reads auth.currentPerson?.avatarUrl)")

        do {
            try await supabase.storage
                .from("photos")
                .upload(path, data: jpegData,
                        options: FileOptions(contentType: "image/jpeg", upsert: false))
            debugLog("[Profile] storage upload succeeded")

            try await supabase
                .from("people")
                .update(["avatar_url": path])
                .eq("id", value: currentId.uuidString)
                .execute()
            debugLog("[Profile] WRITE → people.avatar_url = \(path) (UPDATE succeeded)")

            // Show new image immediately via local data, and update the signed URL so
            // re-appears (when avatarData resets) also show the new photo.
            avatarData = jpegData
            avatarSignedURL = try? await supabase.storage
                .from("photos")
                .createSignedURL(path: path, expiresIn: 3600)
            debugLog("[Profile] avatarSignedURL refreshed to: \(avatarSignedURL?.absoluteString ?? "nil")")

            await auth.refreshCurrentPerson()
            debugLog("[Profile] auth.currentPerson refreshed — avatar_url: \(auth.currentPerson?.avatarUrl ?? "nil")")
        } catch {
            debugLog("[Profile] FAILED — error: \(error)")
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(AuthService())
}
