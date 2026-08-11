import SwiftUI

struct ArticleView: View {
    @Environment(NewsStore.self) private var store
    @Environment(ArticleReadingState.self) private var reading
    @State private var heroOverscroll: CGFloat = 0
    @State private var visibleSectionID: String?
    let story: Story

    private var article: ArticleContent {
        .placeholder(for: story)
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                StretchyHeroImage(
                    imageName: story.imageName,
                    height: 390,
                    overscroll: heroOverscroll
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text(story.title)
                        .font(OvertureTheme.editorial(51))
                        .tracking(-1.8)
                        .lineSpacing(-2)

                    Text(story.deck)
                        .font(OvertureTheme.editorial(23))
                        .foregroundStyle(.secondary)
                        .lineSpacing(6)
                        .padding(.top, 20)

                    BylineView(story: story)
                        .padding(.top, 28)

                    ForEach(Array(article.sections.enumerated()), id: \.element.id) { index, section in
                        ArticleSectionView(section: section, depth: reading.displayedDepth)
                            .id(section.id)

                        if index == 0, story.id == Story.quietFlight.id {
                            WaveformCard()
                        }
                    }

                    Rectangle()
                        .fill(OvertureTheme.cobalt)
                        .frame(width: 46, height: 3)
                        .padding(.top, 44)

                    Text("Overture follows the ideas making tomorrow feel possible.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                        .padding(.bottom, 64)
                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .scrollTargetLayout()
            }
            .containerRelativeFrame(.horizontal)
        }
        .scrollPosition(id: $visibleSectionID, anchor: .top)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, overscroll in
            heroOverscroll = overscroll
        }
        .simultaneousGesture(semanticZoomGesture)
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            if reading.isPinching {
                ReadingDepthStatusPill(depth: reading.displayedDepth, story: story)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                readingDepthMenu

                ShareLink(item: story.title, subject: Text(story.title), message: Text(story.deck))
                    .tint(.primary)
                    .accessibilityLabel("Share article")
            }
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.38)) {
                reading.activate(story)
            }
        }
        .onDisappear {
            withAnimation(.smooth(duration: 0.38)) {
                reading.deactivate(story)
            }
        }
        .accessibilityAction(named: "Show more detail") {
            choose(reading.selectedDepth.offset(by: 1))
        }
        .accessibilityAction(named: "Show less detail") {
            choose(reading.selectedDepth.offset(by: -1))
        }
    }

    private var readingDepthMenu: some View {
        Menu {
            ForEach(ReadingDepth.allCases) { depth in
                Button {
                    choose(depth)
                } label: {
                    Label(
                        "\(depth.title) · \(depth.readingTime(for: story))",
                        systemImage: depth == reading.selectedDepth ? "checkmark" : "circle"
                    )
                }
            }
        } label: {
            Label(reading.displayedDepth.readingTime(for: story), systemImage: "text.magnifyingglass")
                .labelStyle(.titleAndIcon)
                .contentTransition(.numericText())
        }
        .tint(.primary)
        .accessibilityLabel("Reading depth")
    }

    private var semanticZoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.025)
            .onChanged { value in
                if !reading.isPinching {
                    reading.beginPinch()
                }

                let nextDepth = depth(for: value.magnification)
                if nextDepth != reading.displayedDepth {
                    Haptics.selection()
                    withAnimation(.smooth(duration: 0.28)) {
                        reading.preview(nextDepth)
                    }
                }
            }
            .onEnded { value in
                reading.preview(depth(for: value.magnification))
                withAnimation(.smooth(duration: 0.32)) {
                    reading.commitPreview()
                }
            }
    }

    private func depth(for magnification: CGFloat) -> ReadingDepth {
        let rawOffset = log2(max(Double(magnification), 0.2)) * 2.15
        return reading.selectedDepth.offset(by: Int(rawOffset.rounded()))
    }

    private func choose(_ depth: ReadingDepth) {
        guard depth != reading.selectedDepth else { return }
        Haptics.selection()
        withAnimation(.smooth(duration: 0.32)) {
            reading.select(depth)
        }
    }
}

private struct ReadingDepthStatusPill: View {
    let depth: ReadingDepth
    let story: Story

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OvertureTheme.cobalt)

            Text("\(depth.title) · \(depth.readingTime(for: story))")
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading depth \(depth.title), \(depth.readingTime(for: story))")
        .modifier(ReadingDepthStatusPillBackground())
    }
}

private struct ReadingDepthStatusPillBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(0.18)), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.22)))
        }
    }
}

private struct ArticleSectionView: View {
    let section: ArticleSection
    let depth: ReadingDepth

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let heading = section.heading {
                Text(heading)
                    .font(OvertureTheme.editorial(32, weight: .semibold))
                    .tracking(-0.5)
                    .padding(.top, 36)
            }

            Text(section.text(at: depth))
                .id("\(section.id)-\(depth.rawValue)")
                .font(OvertureTheme.editorial(section.heading == nil ? 23 : 21))
                .lineSpacing(8)
                .padding(.top, section.heading == nil ? 28 : 20)
                .textSelection(.enabled)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 8)),
                        removal: .opacity
                    )
                )
        }
    }
}

private struct StretchyHeroImage: View {
    let imageName: String
    let height: CGFloat
    let overscroll: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: proxy.size.width,
                    height: height + overscroll
                )
                .clipped()
                .offset(y: -overscroll)
        }
        .frame(height: height)
    }
}

private struct BylineView: View {
    @Environment(NewsStore.self) private var store
    let story: Story

    var body: some View {
        HStack(spacing: 12) {
            Text("M")
                .font(OvertureTheme.editorial(20))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 44, height: 44)
                .background(.primary, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Mara Bell")
                    .font(.subheadline.weight(.bold))
                Text("August 9, 2026  ·  \(story.readTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.snappy) {
                    store.toggleSaved(story)
                }
            } label: {
                Label(store.isSaved(story) ? "Saved" : "Save", systemImage: store.isSaved(story) ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("save-story")
        }
        .padding(.bottom, 28)
        .overlay(alignment: .bottom) { Divider() }
    }
}

#Preview {
    NavigationStack { ArticleView(story: .quietFlight) }
        .environment(NewsStore())
        .environment(ArticleReadingState())
}
