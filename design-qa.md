# Share extension liquid-metal success UI design QA

## Source and capture

- Primary source: Paper Design liquid-metal circle using the supplied values (`#aaaaaa`, `#ffffff`, repetition `2`, softness `0.1`, red/blue shift `0.3`, distortion `0.07`, contour `0.4`, angle `70`, speed `1`, scale `0.6`).
- Reference still: `/var/folders/2m/j4vdhyw53cl3q9hkz537h56r0000gn/T/codex-clipboard-7e026e39-cf28-41f6-acdc-1c8528b41036.png`.
- Runtime capture: `/tmp/overture-paper-exact-final.png` on iPhone 17 Pro Simulator, iOS 26.5.
- Side-by-side comparison: `/tmp/overture-paper-final-qa.png`.
- Motion capture: `/tmp/overture-paper-exact-motion.mp4`.

## Visual assessment

- Passed: the Swift/Metal implementation preserves Paper's circle coordinate system, contour compression, stripe construction, simplex-noise distortion, and independent red/blue dispersion.
- Passed: the settled frame reproduces the reference's two isolated contour pools, dark metallic field, white cores, and tight chromatic edge bands.
- Passed: the circle geometry is intentional; the square shown earlier was only Paper's preview container.
- Passed: the extra native-glass overlay and custom reading-zone wash were removed, so they no longer blur or reshape the shader output.
- Passed: the large quiet white field remains, and the bubble settles slightly below center at 60% of screen width.
- Passed: `Submitted` remains centered and is revealed by the same morphing circle mask, with no redundant `Done` label or separate pill.
- Passed: the 1.5-screen-width entrance still rises from below and contracts into the final circle.

## Interaction and accessibility

- Success is a one-shot entrance followed by automatic dismissal after two seconds.
- The success notification and two restrained impact haptics align with the visual transition.
- Reduce Motion skips the morph and freezes the shader.
- Reduce Transparency lowers shader distortion and chromatic intensity without substituting a different visual language.
- Failure remains persistent, readable, and manually dismissible.

Final result: passed
