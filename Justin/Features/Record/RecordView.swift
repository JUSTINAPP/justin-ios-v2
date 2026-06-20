import SwiftUI
import PhotosUI

// MARK: - Flow container

struct RecordFlowView: View {
    // Optional pre-filled recipient (e.g. launched from a specific person's page).
    // When set, the flow skips Step 1 and opens directly at the voice recording step.
    var prefillRecipientName: String = ""
    var prefillRecipientId:   UUID?  = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: RecordFlowModel
    @State private var path: NavigationPath

    init(prefillRecipientName: String = "", prefillRecipientId: UUID? = nil) {
        self.prefillRecipientName = prefillRecipientName
        self.prefillRecipientId   = prefillRecipientId

        let m = RecordFlowModel()
        var initialPath = NavigationPath()
        if !prefillRecipientName.isEmpty, let pid = prefillRecipientId {
            m.recipientName     = prefillRecipientName
            m.recipientPersonId = pid
            m.isNewRecipient    = false
            initialPath.append(RecordStep.voice)
        }
        _model = StateObject(wrappedValue: m)
        _path  = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            RecordStep1WhoView(path: $path, onCancel: { dismiss() })
                .navigationDestination(for: RecordStep.self) { step in
                    switch step {
                    case .voice:   RecordStep2VoiceView(path: $path)
                    case .photos:  RecordStep3PhotosView(path: $path)
                    case .when:    RecordStep4WhenView(path: $path)
                    case .preview: RecordStep5PreviewView(path: $path, onDone: { dismiss() })
                    case .invite:  InviteShareView(onDone: { dismiss() })
                    case .share:
                        let _ = {
                            print("[ShareDebug] navigationDestination .share — model.savedShareToken at view-build time: \(model.savedShareToken ?? "nil")")
                            print("[ShareDebug] navigationDestination .share — model.savedGiftId at view-build time: \(model.savedGiftId?.uuidString ?? "nil")")
                            print("[ShareDebug] navigationDestination .share — SOURCE: RecordFlowView model (id: \(ObjectIdentifier(model)))")
                        }()
                        GiftShareView(
                            recipientName: model.recipientName,
                            shareToken: model.savedShareToken,
                            onDone: { dismiss() }
                        )
                    }
                }
        }
        .environmentObject(model)
    }
}

// MARK: - Step identifier

enum RecordStep: Hashable { case voice, photos, when, preview, invite, share }

// ─────────────────────────────────────────────
// MARK: - Step 1: Who's it for?
// ─────────────────────────────────────────────

struct RecordStep1WhoView: View {
    @Binding var path: NavigationPath
    let onCancel: () -> Void
    @EnvironmentObject var model: RecordFlowModel
    @EnvironmentObject var auth: AuthService

    @StateObject private var peopleVM = PeopleViewModel()
    @State private var showNewPersonField = false
    @State private var newPersonName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        StepShell(
            step: "1 of 5",
            title: "Who's this for?",
            isNextEnabled: !model.recipientName.isEmpty,
            next: { path.append(RecordStep.voice) }
        ) {
            VStack(spacing: 10) {
                if peopleVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                ForEach(peopleVM.people) { person in
                    Button {
                        model.recipientName = person.name
                        model.recipientPersonId = person.id
                        model.isNewRecipient = false
                        model.recipientPhone = ""
                        withAnimation(.spring(duration: 0.3)) { showNewPersonField = false }
                        newPersonName = ""
                    } label: {
                        HStack(spacing: 14) {
                            InitialsAvatar(name: person.name, size: 40)
                            Text(person.name)
                                .font(.system(.body).weight(.medium))
                                .foregroundColor(.primary)
                            Spacer()
                            if model.recipientPersonId == person.id && !showNewPersonField {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandPurple)
                            }
                        }
                        .padding(14)
                        .background(
                            model.recipientPersonId == person.id && !showNewPersonField
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
                        // Always clear any existing selection — the typed name is the only source
                        model.recipientName = ""
                        model.recipientPersonId = nil
                        model.isNewRecipient = false
                        newPersonName = ""
                    } else {
                        // Closing — clear new-person fields and deselect
                        newPersonName = ""
                        model.recipientPhone = ""
                        model.recipientName = ""
                        model.recipientPersonId = nil
                        model.isNewRecipient = false
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
                    VStack(spacing: 8) {
                        TextField("Their name", text: $newPersonName)
                            .textFieldStyle(.plain)
                            .font(.system(.body))
                            .padding(14)
                            .background(Color(.systemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .focused($fieldFocused)
                            .onChange(of: newPersonName) { _, value in
                                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                                model.recipientName = trimmed
                                model.recipientPersonId = nil   // never carry an existing person's id into a new-person save
                                model.isNewRecipient = !trimmed.isEmpty
                            }

                        VStack(alignment: .leading, spacing: 5) {
                            PhoneNumberField(normalised: $model.recipientPhone)
                            Text("Optional — helps your gift reach them when they join.")
                                .font(.system(.caption))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
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
        .onAppear {
            guard let id = auth.currentPerson?.id else { return }
            Task { await peopleVM.fetch(currentPersonId: id) }
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
    @Environment(\.dismiss) private var dismiss

    @State private var sparkPage = 0

    private static let sparks: [(String, String)] = [
        ("A memory of you two that always makes you smile",
         "Something you've never said out loud"),
        ("Tell them what makes you proud of them",
         "A simple thank you they've been waiting to hear"),
        ("What you hope for them in the years ahead",
         "A piece of advice you wish someone had given you"),
    ]

    private var isRecording: Bool { recorder.recordState == .recording }
    private var isDone:      Bool { recorder.recordState == .done }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.recordingBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 110)

                topSection

                Spacer(minLength: 36)

                // Middle: spark suggestions (idle) or waveform (recording); empty when done
                Group {
                    if isRecording {
                        waveformSection.transition(.opacity)
                    } else if !isDone {
                        sparkSection.transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: recorder.recordState)

                Spacer(minLength: 24)

                // Time — only while recording
                if isRecording {
                    timeView
                        .padding(.bottom, 24)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }

                // Record / stop button
                recordButtonArea
                    .padding(.bottom, 10)

                // State label below button
                Text(belowButtonLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .id(recorder.recordState)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: recorder.recordState)
                    .padding(.bottom, isDone ? 24 : 0)

                // Continue — only when done
                if isDone {
                    continueSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(duration: 0.35, bounce: 0.1), value: isDone)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topLeading) { closeButton }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Close

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(10)
                .background(.white.opacity(0.12))
                .clipShape(Circle())
        }
        .padding(.top, 56)
        .padding(.leading, 20)
    }

    // MARK: - Top section

    private var topSection: some View {
        VStack(spacing: 12) {
            InitialsAvatar(
                name: model.recipientName.isEmpty ? "?" : model.recipientName,
                size: 52
            )

            Text(isRecording
                 ? "Speaking to \(model.recipientName)"
                 : "Say something to \(model.recipientName)")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !isRecording && !isDone {
                Text("Just talk to them like they're here")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: recorder.recordState)
    }

    // MARK: - Spark suggestions

    @ViewBuilder
    private var sparkSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    sparkPage = (sparkPage + 1) % Self.sparks.count
                }
            } label: {
                Text("Need a spark?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .buttonStyle(.plain)

            let pair = Self.sparks[sparkPage]
            VStack(spacing: 8) {
                sparkCard(pair.0)
                sparkCard(pair.1)
            }
        }
        .padding(.horizontal, 28)
    }

    private func sparkCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }

    // MARK: - Live waveform

    private var waveformSection: some View {
        LiveWaveform(levels: recorder.meterLevels, active: true)
            .frame(height: 80)
            .padding(.horizontal, 28)
    }

    // MARK: - Time display

    private var timeView: some View {
        let secs = recorder.elapsedSeconds
        let label = secs < 8
            ? secs.asTimeCode
            : "\(secs.asTimeCode) · a little longer is lovely"
        return Text(label)
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
    }

    // MARK: - Record / stop button

    private var recordButtonArea: some View {
        Button {
            switch recorder.recordState {
            case .idle, .done:
                recorder.requestAndStart()
            case .recording:
                recorder.stop()
                model.audioURL = recorder.recordingURL
            }
        } label: {
            RecordButton(state: recorder.recordState)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Label text

    private var belowButtonLabel: String {
        switch recorder.recordState {
        case .idle:      return "Tap to start"
        case .recording: return "Tap to finish"
        case .done:      return "Tap to re-record"
        }
    }

    // MARK: - Continue

    private var continueSection: some View {
        Button {
            path.append(RecordStep.photos)
        } label: {
            Text("Continue")
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.brandPurple)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 28)
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
            title: "Add photos or words",
            next: { path.append(RecordStep.when) }
        ) {
            VStack(spacing: 20) {

                // ── Photos ──────────────────────────────────────

                VStack(alignment: .leading, spacing: 12) {
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

                Divider()

                // ── Words ────────────────────────────────────────

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a few words")
                        .font(.system(.subheadline).weight(.medium))

                    Text("Optional. Appears on screen while your voice plays.")
                        .font(.system(.caption))
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        if model.messageCaption.isEmpty {
                            Text("Write something…")
                                .font(.custom("Caveat", size: 19))
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 10)
                                .padding(.leading, 12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $model.messageCaption)
                            .font(.custom("Caveat", size: 19))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 90)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .padding(4)
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        if model.hasCaption {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.brandPurple.opacity(0.3), lineWidth: 1)
                        }
                    }

                    if model.hasCaption {
                        Button("Clear") {
                            model.messageCaption = ""
                        }
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                    }
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
    @State private var customFeeling = ""

    private let feelingPresets = ["when you miss me", "when you can't sleep", "when it's a hard day"]

    private var isStepComplete: Bool {
        switch model.releaseType {
        case .now, .date, .always: return true
        case .feeling:             return !model.releaseFeeling.isEmpty
        }
    }

    var body: some View {
        StepShell(
            step: "4 of 5",
            title: "When does it open?",
            isNextEnabled: isStepComplete,
            next: { path.append(RecordStep.preview) }
        ) {
            VStack(spacing: 10) {

                releaseRow(.now)

                releaseRow(.date)
                if model.releaseType == .date {
                    dateSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                releaseRow(.feeling)
                if model.releaseType == .feeling {
                    feelingSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                releaseRow(.always)
            }
        }
        .onAppear {
            // Re-populate custom field if returning to this step with a non-preset feeling
            if model.releaseType == .feeling && !feelingPresets.contains(model.releaseFeeling) {
                customFeeling = model.releaseFeeling
            }
        }
    }

    // MARK: - Release type row

    private func releaseRow(_ type: ReleaseType) -> some View {
        let selected = model.releaseType == type
        return Button {
            withAnimation(.spring(duration: 0.3)) { model.releaseType = type }
        } label: {
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

    // MARK: - Date section

    private var dateSection: some View {
        VStack(spacing: 10) {
            DatePicker(
                "Open on",
                selection: $model.releaseDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(.brandPurple)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Toggle(isOn: $model.hiddenUntilRelease) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hide until the day")
                        .font(.system(.body).weight(.medium))
                    Text("A surprise — they won't know it's coming")
                        .font(.system(.caption))
                        .foregroundColor(.secondary)
                }
            }
            .tint(.brandPurple)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Feeling section

    private var feelingSection: some View {
        VStack(spacing: 8) {
            ForEach(feelingPresets, id: \.self) { preset in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        model.releaseFeeling = preset
                        customFeeling = ""
                    }
                } label: {
                    HStack {
                        Text(preset)
                            .font(.system(.body))
                            .foregroundColor(.primary)
                        Spacer()
                        if model.releaseFeeling == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brandPurple)
                        }
                    }
                    .padding(14)
                    .background(
                        model.releaseFeeling == preset
                            ? Color.brandPurple.opacity(0.09)
                            : Color(.systemFill)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            // Custom feeling
            HStack(spacing: 8) {
                TextField("or write your own...", text: $customFeeling)
                    .textFieldStyle(.plain)
                    .font(.system(.body))
                    .onChange(of: customFeeling) { _, value in
                        model.releaseFeeling = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                if !customFeeling.isEmpty {
                    Button {
                        customFeeling = ""
                        model.releaseFeeling = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
            .padding(14)
            .background(
                !customFeeling.isEmpty
                    ? Color.brandPurple.opacity(0.09)
                    : Color(.systemFill)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if !customFeeling.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.brandPurple.opacity(0.3), lineWidth: 1)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Step 5: Preview & send
// ─────────────────────────────────────────────

struct RecordStep5PreviewView: View {
    @Binding var path: NavigationPath
    let onDone: () -> Void
    @EnvironmentObject var model: RecordFlowModel
    @EnvironmentObject var auth: AuthService
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private var releaseDescription: String {
        switch model.releaseType {
        case .now:
            return "Opens right away"
        case .date:
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            let dateStr = f.string(from: model.releaseDate)
            return model.hiddenUntilRelease ? "Opens \(dateStr) · A surprise" : "Opens \(dateStr)"
        case .feeling:
            return model.releaseFeeling.isEmpty ? "Opens when the moment is right" : "Opens \(model.releaseFeeling)"
        case .always:
            return "Always there for them"
        }
    }

    var body: some View {
        ZStack {
            // Background player — photos + audio; caption: nil because words are
            // displayed in the preview overlay below (constrained, never overlaps button).
            KenBurnsPlayerView(
                fromName: auth.currentPerson?.displayName ?? "Me",
                localImages: model.selectedImages,
                showControls: false,
                caption: nil,
                localAudioURL: model.audioURL,
                showCenterPlayButton: true
            )

            // ── Preview-only overlay ────────────────────────────────────────────
            VStack(spacing: 0) {

                // Title header — tells the gifter who this is for and when it opens.
                // Preview-only metadata; the recipient never sees this.
                VStack(spacing: 5) {
                    Text("For \(model.recipientName)")
                        .font(.system(.title3).weight(.bold))
                        .foregroundStyle(.white)
                    Text(releaseDescription)
                        .font(.system(.subheadline).weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 72)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.50), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                Spacer()

                // Typed words — constrained area above the button.
                // Never overlaps with "Add to gift" because it is bounded here
                // and the Spacer() above absorbs slack, not this region.
                if model.hasCaption {
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(model.messageCaption)
                            .font(.custom("Caveat", size: 22))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: 110)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
                }

                // Add to gift — the sole call to action for the gifter
                Button {
                    Task { await saveAndFinish() }
                } label: {
                    Group {
                        if isSaving {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white)
                                Text("Uploading…")
                                    .font(.system(.body).weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        } else {
                            Text("Add to gift")
                                .font(.system(.body).weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brandPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isSaving)
                .padding(.horizontal, 28)

                // Bottom safe-area clearance (no controls bar — showControls: false)
                Spacer().frame(height: 48)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })) {
            Button("OK") {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func saveAndFinish() async {
        // Snapshot any pre-existing token to spot stale-model reuse
        print("[ShareDebug] saveAndFinish — model.savedShareToken BEFORE save: \(model.savedShareToken ?? "nil")")
        print("[ShareDebug] saveAndFinish — model.savedGiftId    BEFORE save: \(model.savedGiftId?.uuidString ?? "nil")")

        guard let authorId = auth.currentPerson?.id else {
            print("[ShareDebug] saveAndFinish — no authenticated person, navigating to .share with nil token")
            path.append(RecordStep.share)
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let result = try await GiftSaveService().save(model: model, authorId: authorId)

            print("[ShareDebug] saveAndFinish — GiftSaveService returned giftId: \(result.giftId?.uuidString ?? "nil"), shareToken: \(result.shareToken ?? "nil"), recipientIsVerified: \(result.recipientIsVerified)")

            model.savedGiftId     = result.giftId
            model.savedShareToken = result.shareToken

            print("[ShareDebug] saveAndFinish — model.savedShareToken AFTER set: \(model.savedShareToken ?? "nil")")

            if result.recipientIsVerified {
                // Recipient has the Justin app — message lands on their shelf in-app.
                // No shareable link needed; skip the share screen.
                print("[ShareDebug] recipient IS verified → onDone() (in-app delivery, no share screen)")
                onDone()
            } else {
                // Recipient doesn't have the app yet — show the share screen.
                // SQL creates a fresh gift + token per message (see create_gift_with_message migration).
                print("[ShareDebug] recipient NOT verified → navigating to .share")
                path.append(RecordStep.share)
            }
        } catch {
            print("[Save] gift save failed: \(error)")
            saveError = "Couldn't upload your message. Please check your connection and try again."
        }
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
            // Outer translucent ring
            Circle()
                .strokeBorder(Color.recordRose.opacity(0.28), lineWidth: 2.5)
                .frame(width: 80, height: 80)

            switch state {
            case .idle:
                // Rose circle + mic — the invitation to record
                Circle()
                    .fill(Color.recordRose)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
            case .recording:
                // Tinted ring + stop square
                Circle()
                    .fill(Color.recordRose.opacity(0.18))
                    .frame(width: 60, height: 60)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.recordRose)
                            .frame(width: 22, height: 22)
                    }
            case .done:
                // Dimmed mic — tapping starts a new recording
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.45))
                    }
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

    private static let roseGradient = LinearGradient(
        colors: [Color(hex: "D4537E"), Color(hex: "F4C0D1")],
        startPoint: .bottom, endPoint: .top
    )
    private static let idleGradient = LinearGradient(
        colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
        startPoint: .bottom, endPoint: .top
    )

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(active ? Self.roseGradient : Self.idleGradient)
                    .frame(width: 4, height: max(4, levels[i] * 72))
            }
        }
        .animation(.easeInOut(duration: 0.08), value: levels)
    }
}

// MARK: - Preview

#Preview { RecordFlowView() }
