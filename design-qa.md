# Header Design QA

## Evidence

- Source visual truth: `/Users/maxwiseman/Pictures/Photos Library.photoslibrary/resources/renders/7/76BC14EF-F02B-4CEC-9217-4F8FC5B5E8DA_1_201_a.jpeg`
- Source intent: the supplied image documents the previous oversized avatar and visible gray blur seam; the requested target is a toolbar-sized glass circle with an enlarged `M`, plus a header treatment that matches the feed background and protects the wordmark while content scrolls beneath it.
- Implementation screenshot: `/Users/maxwiseman/Projects/news/overture/design-qa-implementation.jpg`
- Focused comparison: `/Users/maxwiseman/Projects/news/overture/design-qa-header-comparison.jpg` (previous state left, revised implementation right)
- Simulator viewport: iPhone 17 Pro, iOS 26.5, 368 x 800 screenshot pixels.
- Source pixels: 1179 x 484. Implementation pixels: 368 x 800.
- Density normalization: the source was scaled to 368 x 150 and compared with a 368 x 150 top crop of the implementation. The comparison is focused on the persistent header rather than unrelated feed content.
- State: Home tab scrolled so the first feed story passes behind the persistent header.

## Findings

No actionable P0, P1, or P2 differences remain for the requested header correction.

- Fonts and typography: the Overture editorial wordmark remains unchanged; the avatar restores the requested `M` at 18 points and remains optically centered.
- Spacing and layout rhythm: the visible glass circle is 36 points inside a standard 44-point hit target. Header horizontal alignment remains consistent with the feed's 24-point inset.
- Colors and visual tokens: on iOS 26, the header uses `safeAreaBar` with the system `.soft` scroll-edge effect. The stationary bar inherits the screen's exact `OvertureTheme.ink` background, while SwiftUI supplies blur only where scrolling content overlaps it. The custom tint and material masks remain solely as the iOS 18–25 fallback.
- Image quality and asset fidelity: no image assets were changed. The lead and story images remain sharp and correctly cropped.
- Copy and content: the wordmark and profile initial match the requested content.
- Interaction: the profile button remained hittable after scrolling and successfully presented the Profile sheet.

## Comparison History

1. Earlier P1: the standard glass button style added padding around a 42-point symbol, producing an oversized control. Fixed by applying interactive glass directly to a 36-point circular label inside a 44-point button frame.
2. Earlier P1: the hand-authored gradient did not reliably balance title protection, blur strength, and background color.
3. Earlier P2: SwiftUI `Material` brightened the empty `ink` background and exposed the fade boundary.
4. Final fix: on iOS 26, `safeAreaBar(edge: .top)` now owns the stationary header and `.scrollEdgeEffectStyle(.soft, for: .top)` supplies the native progressive overlap blur.
5. Post-fix evidence: the simulator capture shows strongly blurred scrolling copy behind a crisp wordmark, with no custom gray overlay in the stationary bar.

## Follow-up Polish

- P3: assess the system soft edge effect on a physical device; Apple controls its exact blur curve and appearance.

## Implementation Checklist

- [x] Toolbar-sized profile control
- [x] Initials restored
- [x] Native interactive Liquid Glass on iOS 26
- [x] Earlier-iOS material fallback retained
- [x] Stronger wordmark protection
- [x] Blur layer matches the feed background
- [x] Native iOS 26 soft scroll-edge effect
- [x] Profile uses one non-resizable large detent
- [x] Downward sheet dismissal verified
- [x] Simulator build and interaction verification

final result: passed
