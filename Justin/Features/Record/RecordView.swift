import SwiftUI
import PhotosUI

// MARK: - Flow container

struct RecordFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RecordFlowModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            RecordStep1WhoView(path: $path, onCancel: { dismiss() })
                .navigationDestination(for: RecordStep.self) { step in
                    switch step {
                    case .voice:   RecordStep2VoiceView(path: $path)
                    case .photos:  RecordStep3PhotosView(path: $path)
                    case .when:    RecordStep4WhenView(path: $path)
                    case .preview: RecordStep5PreviewView(onDone: { dismiss() })
                    }
                }
        }
        .environmentObject(model)
    }
}

// MARK: - Step identifier

enum RecordStep: Hashable { case voice, photos, when, preview }

// ─────────────────────────────────────────────
// MARK: - Step 1: Who's it for?
// ─────────────────────────────────────────────

struct RecordStep1WhoView: View {
    @Binding var path: NavigationPath
    let onCancel: () -> Void
    @EnvironmentObject var model: RecordFlowModel

    @State private var showNewPersonField = false
    @State private var newPersonName = ""
    @FocusState private var fieldFocused: Bool

    private let people = ["Mum", "Em", "Jordan"]

    var body: some View {
        StepShell(
            step: "1 of 5",
            title: "Who's this for?",
            isNextEnabled: !model.recipientName.isEmpty,
            next: { path.append(RecordStep.voice) }
        ) {
            VStack(spacing: 10) {
                ForEach(people, id: \.self) { name in
                    Button {
                        model.recipientName = name
                        withAnimation(.spring(duration: 0.3)) { showNewPersonField = false }
                        newPersonName = ""
                    } label: {
                        HStack(spacing: 14) {
                            InitialsAvatar(name: name, size: 40)
                            Text(name)
                                .font(.system(.body).weight(.medium))
                                .foregroundColor(.primary)
                            Spacer()
                            if model.recipientName == name && !showNewPersonField {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                            }
                        }
                        .padding(14)
                        .background(
                            model.recipientName == name && !showNewPersonField
                                ? Color.brandPurple.opacity(0.09)
                                : Color(.systemFill)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                // "Add someone new" toggle row
                Button {
                    let opening = !showNewPersonField
                    withAnimation(.spring(duration: 0.3)) { showNewPersonField = opening }
                    if opening {
                        // Deselect any list person so the typed name is the only source
                        if people.contains(model.recipientName) { model.recipientName = "" }
                    } else {
                        // Closing without a typed name — clear everything
                        newPersonName = ""
                        if !people.contains(model.recipientName) { model.recipientName = "" }
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPurple.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.brandPurple)
                        }
                        Text("Add someone new")
                            .font(.system(.body).weight(.medium))
                            .foregroundColor(.brandPurple)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(showNewPersonField ? 180 : 0))
                            .animation(.spring(duration: 0.3), value: showNewPersonField)
                    }
                    .padding(14)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                if showNewPersonField {
                    TextField("Their name", text: $newPersonName)
                        .textFieldStyle(.plain)
                        .font(.system(.body))
                        .padding(14)
                        .background(Color(.systemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($fieldFocused)
                        .onChange(of: newPersonName) { _, value in
                            model.recipientName = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: showNewPersonField) { _, newValue in
                if newValue { fieldFocused = true }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { onCancel() }.foregroundColor(.secondary)
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Step 2: Record voice
// ─────────────────────────────────────────────

struct RecordStep2VoiceView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var model: RecordFlowModel
    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        StepShell(
            step: "2 of 5",
            title: "Say something to \(model.recipientName)",
            isNextEnabled: recorder.recordState == .done,
            next: { path.append(RecordStep.photos) }
        ) {
            VStack(spacing: 28) {
                Text(recorder.elapsedSeconds.asTimeCode)
                    .font(.system(size: 52, weight: .thin, design: .monospaced))
                    .foregroundColor(recorder.recordState == .recording ? .primary : .secondary)
                    .animation(.easeInOut(duration: 0.25), value: recorder.recordState)

                LiveWaveform(
                    levels: recorder.meterLevels,
                    active: recorder.recordState == .recording
                )
                .frame(height: 60)
                .opacity(recorder.recordState == .idle ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: recorder.recordState)

                Button {
                    switch recorder.recordState {
                    case .idle, .done: recorder.requestAndStart()
                    case .recording:
                        recorder.stop()
                        model.audioURL = recorder.recordingURL
                    }
                } label: {
                    RecordButton(state: recorder.recordState)
                }
                .buttonStyle(.plain)

                Group {
                    switch recorder.recordState {
                    case .idle:
                        Text("Tap to start recording").foregroundColor(.secondary)
                    case .recording:
                        Text("Recording — tap to stop").foregroundColor(.red)
                    case .done:
                        Label("Message recorded", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .font(.system(.subheadline))
                .animation(.easeInOut, value: recorder.recordState)

                if recorder.recordState == .done {
                    Button("Re-record") {
                        recorder.discard()
                        model.audioURL = nil
                    }
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Step 3: Add photos
// ─────────────────────────────────────────────

struct RecordStep3PhotosView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var model: RecordFlowModel
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        StepShell(
            step: "3 of 5",
            title: "Add photos",
            nextLabel: model.hasPhotos ? "Next" : "Skip — just my voice",
            next: { path.append(RecordStep.when) }
        ) {
            VStack(spacing: 20) {
                if model.hasPhotos {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(model.selectedImages.indices, id: \.self) { i in
                                Image(uiImage: model.selectedImages[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label(
                        model.hasPhotos ? "Change photos" : "Choose photos",
                        systemImage: "photo.on.rectangle"
                    )
                    .font(.system(.body).weight(.medium))
                    .foregroundColor(.brandPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandPurple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.brandPurple.opacity(0.25), lineWidth: 1)
                    }
                }

                if model.hasPhotos {
                    Button("Remove all photos") {
                        model.selectedImages = []
                        pickerItems = []
                    }
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { @MainActor in
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        images.append(img)
                    }
                }
                model.selectedImages = images
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Step 4: When does it open?
// ─────────────────────────────────────────────

struct RecordStep4WhenView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var model: RecordFlowModel

    var body: some View {
        StepShell(
            step: "4 of 5",
            title: "When does it open?",
            next: { path.append(RecordStep.preview) }
        ) {
            VStack(spacing: 10) {
                ForEach([ReleaseType.now, .date, .feeling, .always], id: \.self) { type in
                    releaseRow(type)
                }

                if model.releaseType == .date {
                    DatePicker("Open on", selection: $model.releaseDate,
                               in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.top, 6)
                }

                if model.releaseType == .feeling {
                    TextField("e.g. you can't sleep", text: $model.releaseFeeling)
                        .textFieldStyle(.roundedBorder)
                        .padding(.top, 6)
                }
            }
        }
    }

    private func releaseRow(_ type: ReleaseType) -> some View {
        let selected = model.releaseType == type
        return Button { model.releaseType = type } label: {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .foregroundColor(selected ? .brandPurple : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.primary)
                    Text(type.releaseSubtitle)
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.brandPurple)
                }
            }
            .padding(14)
            .background(selected ? Color.brandPurple.opacity(0.09) : Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// ─────────────────────────────────────────────
// MARK: - Step 5: Preview & send
// ─────────────────────────────────────────────

struct RecordStep5PreviewView: View {
    let onDone: () -> Void
    @EnvironmentObject var model: RecordFlowModel
    @StateObject private var player = AudioPlayer()

    var body: some View {
        ZStack {
            if model.hasPhotos {
                // TODO: Replace with KenBurnsPlayerView once it accepts UIImage input
                TabView {
                    ForEach(model.selectedImages.indices, id: \.self) { i in
                        Image(uiImage: model.selectedImages[i])
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [.brandPurple, .brandDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .center, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                Text("For \(model.recipientName)")
                    .font(.system(.subheadline).weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 4)

                Button { player.playPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8)
                }
                .padding(.bottom, 12)

                ProgressView(value: player.duration > 0 ? player.currentTime / player.duration : 0)
                    .tint(.white)
                    .padding(.horizontal, 40)

                HStack {
                    Text(player.currentTime.asTimeCode)
                    Spacer()
                    Text(player.duration.asTimeCode)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 40)
                .padding(.top, 4)

                Spacer()

                Button {
                    player.stop()
                    // TODO: Upload audio + photos to Supabase Storage,
                    //       insert record into messages table, link to gift
                    onDone()
                } label: {
                    Text("Add to gift")
                        .font(.system(.body).weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Preview")
                    .font(.system(.subheadline).weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { if let url = model.audioURL { player.load(url: url) } }
        .onDisappear { player.stop() }
    }
}

// ─────────────────────────────────────────────
// MARK: - Shared step shell
// ─────────────────────────────────────────────

/// Standard step chrome: step counter, title, sticky Next button.
/// `isNextEnabled` gates only the Next button — content remains interactive.
private struct StepShell<Content: View>: View {
    let step: String
    let title: String
    var nextLabel: String
    var isNextEnabled: Bool
    let next: () -> Void
    let content: Content

    init(
        step: String,
        title: String,
        nextLabel: String = "Next",
        isNextEnabled: Bool = true,
        next: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.step = step
        self.title = title
        self.nextLabel = nextLabel
        self.isNextEnabled = isNextEnabled
        self.next = next
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(step)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                Text(title)
                    .font(.system(.title2).weight(.semibold))
                    .padding(.bottom, 24)

                content
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: next) {
                Text(nextLabel)
                    .font(.system(.body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isNextEnabled ? Color.brandPurple : Color.secondary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isNextEnabled)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ─────────────────────────────────────────────
// MARK: - Record button
// ─────────────────────────────────────────────

private struct RecordButton: View {
    let state: AudioRecorder.RecordState

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.primary.opacity(0.15), lineWidth: 3)
                .frame(width: 88, height: 88)

            switch state {
            case .idle:
                Circle()
                    .fill(.red)
                    .frame(width: 66, height: 66)
            case .recording:
                RoundedRectangle(cornerRadius: 6)
                    .fill(.red)
                    .frame(width: 30, height: 30)
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.green)
            }
        }
        .animation(.spring(duration: 0.25), value: state)
    }
}

// ─────────────────────────────────────────────
// MARK: - Live waveform
// ─────────────────────────────────────────────

private struct LiveWaveform: View {
    let levels: [CGFloat]
    let active: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(active ? Color.red.opacity(0.85) : Color.secondary.opacity(0.4))
                    .frame(width: 4, height: max(4, levels[i] * 56))
            }
        }
        .animation(.easeInOut(duration: 0.08), value: levels)
    }
}

// MARK: - Preview

#Preview { RecordFlowView() }
