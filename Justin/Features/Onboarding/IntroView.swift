import SwiftUI

struct IntroView: View {
    var onDone: () -> Void

    @State private var currentPage = 0

    private let slides: [IntroSlide] = [
        IntroSlide(
            illustration: "illus-hands-face",
            heading: "Voice messages that arrive when they're needed.",
            body: "Leave your voice for someone you love, ready to open whenever the moment is right."
        ),
        IntroSlide(
            illustration: "illus-hand-flower",
            heading: "For the moments that matter.",
            body: "A birthday. A hard day. A first night away from home. Your voice, there for all of them."
        ),
        IntroSlide(
            illustration: "illus-hug-arms",
            heading: "Always there when you need them.",
            body: "Messages that don't disappear. A shelf of voices from the people who love you most."
        ),
    ]

    private var isLastSlide: Bool { currentPage == slides.count - 1 }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            TabView(selection: $currentPage) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideContent(slide)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 0) {
                pageIndicator
                    .padding(.bottom, 28)

                Button {
                    if isLastSlide {
                        onDone()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    }
                } label: {
                    Text(isLastSlide ? "Get started" : "Next")
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 28)

                if isLastSlide {
                    Color.clear.frame(height: 52)
                } else {
                    Button("Skip", action: onDone)
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                        .frame(height: 36)
                }
            }
            .padding(.bottom, 48)
        }
    }

    private func slideContent(_ slide: IntroSlide) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(slide.illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 220, maxHeight: 220)
                .opacity(0.88)
                .padding(.bottom, 44)

            VStack(spacing: 14) {
                Text(slide.heading)
                    .font(.system(.title2, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ink)

                Text(slide.body)
                    .font(.system(.body))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 36)

            // Spacer that accounts for the bottom control strip height
            Color.clear.frame(height: 192)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<slides.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage
                          ? Color.brandPurple
                          : Color.brandPurple.opacity(0.2))
                    .frame(width: index == currentPage ? 20 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }
}

private struct IntroSlide {
    let illustration: String
    let heading: String
    let body: String
}

#Preview {
    IntroView(onDone: {})
}
