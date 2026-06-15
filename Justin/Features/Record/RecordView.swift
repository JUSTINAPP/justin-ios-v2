import SwiftUI

// MARK: - Flow container

struct RecordFlowView: View {
    @Environment(\.dismiss) private var dismiss
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
    }
}

// MARK: - Step identifier

enum RecordStep: Hashable {
    case voice, photos, when, preview
}

// MARK: - Step 1: Who's it for?

struct RecordStep1WhoView: View {
    @Binding var path: NavigationPath
    let onCancel: () -> Void

    var body: some View {
        RecordStepShell(
            step: "1 of 5",
            title: "Who's it for?",
            subtitle: "Pick someone from your people, or add someone new."
        ) {
            path.append(RecordStep.voice)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { onCancel() }
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Step 2: Record your voice

struct RecordStep2VoiceView: View {
    @Binding var path: NavigationPath

    var body: some View {
        RecordStepShell(
            step: "2 of 5",
            title: "Record your voice",
            subtitle: "Tap and hold to record. Even ten seconds is a gift."
        ) {
            path.append(RecordStep.photos)
        }
        // TODO: AVAudioRecorder session + waveform visualizer goes here
    }
}

// MARK: - Step 3: Add photos

struct RecordStep3PhotosView: View {
    @Binding var path: NavigationPath

    var body: some View {
        RecordStepShell(
            step: "3 of 5",
            title: "Add photos",
            subtitle: "Optional. Your voice will play over them with a slow, gentle pan.\nNo photo is perfectly fine."
        ) {
            path.append(RecordStep.when)
        }
        // TODO: PHPickerViewController integration goes here
    }
}

// MARK: - Step 4: When does this open?

struct RecordStep4WhenView: View {
    @Binding var path: NavigationPath

    var body: some View {
        RecordStepShell(
            step: "4 of 5",
            title: "When does this open?",
            subtitle: "Now, on a date, when a feeling hits, or always available."
        ) {
            path.append(RecordStep.preview)
        }
        // TODO: ReleaseType picker (now / date / feeling / always) goes here
    }
}

// MARK: - Step 5: Preview

struct RecordStep5PreviewView: View {
    let onDone: () -> Void

    var body: some View {
        RecordStepShell(
            step: "5 of 5",
            title: "Preview",
            subtitle: "This is how it will feel when they open it.",
            nextLabel: "Send it",
            action: onDone
        )
        // TODO: KenBurnsPlayerView preview with recorded content goes here
    }
}

// MARK: - Shared step shell

private struct RecordStepShell: View {
    let step: String
    let title: String
    let subtitle: String
    var nextLabel: String = "Next"
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(step)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundColor(.secondary)
                .padding(.bottom, 14)

            Text(title)
                .font(.system(.title2).weight(.semibold))
                .padding(.bottom, 10)

            Text(subtitle)
                .font(.system(.body))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: action) {
                Text(nextLabel)
                    .font(.system(.body).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brandPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    RecordFlowView()
}
