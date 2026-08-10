# CleanMyScreen design QA

## Evidence

- Selected source: `Design/cleanmyscreen-option-1.png` — 1487 × 1058 px concept board, Cleaning mode, idle state.
- Final implementation: `Design/implementation-cleaning-final.png` — 920 × 760 px native macOS window, Cleaning mode, idle state.
- Combined comparison: `Design/design-qa-comparison-final.png` — source on the left and implementation on the right, normalized to equal 920 × 760 panels.
- Additional state captures: `Design/implementation-pet-v1.png` and `Design/implementation-selective-v1.png`.
- Functional inspection: all three mode tabs, configuration controls, primary-action labels, auto-unlock value, and the three-second Escape footer were present in the macOS accessibility tree. The lock-start action was intentionally not triggered during visual QA.

The source is a rendered concept that includes desktop wallpaper around its window, so the comparison preserves the full concept rather than pretending its outer pixels are an application viewport. The implementation evidence uses the app's real default 920 × 760 window. The native app has a 760 × 670 minimum size and uses `ViewThatFits` fallbacks for narrower control layouts. Browser console and mobile/tablet viewport checks do not apply to this native macOS client.

## Comparison findings

- P0/P1/P2: none. Content order, central monitor preview, segmented mode selector, three-setting row, primary action, footer escape instruction, typography hierarchy, spacing, card radii, blue accent, SF Symbols, and light macOS surface treatment all preserve the selected direction.
- P3 — system switch tint: the concept renders enabled switches blue. Automated window capture renders native macOS switches gray while the app is not the active input owner; accessibility inspection still reports both Cleaning switches as `on`. Kept the system switch rather than replacing it with a simulated control.
- P3 — title-bar treatment: the concept centers its window title, while the packaged app follows the current standard macOS title-bar placement. This is an intentional native adaptation and does not affect hierarchy or use.
- Accessibility: native buttons, toggles, picker, labels, selected traits, preview descriptions, and the emergency-unlock instruction are exposed semantically. Contrast remains strong; primary controls meet practical desktop target sizes. Motion is limited to short state transitions and a countdown.
- State coverage: Pet / Kid mode keeps the display preview visible and presents locked Keyboard/Trackpad cards. Selective mode exposes independent Keyboard, Trackpad, and External switches with the external-device experimental label. No clipping or control overlap was observed at the default window size.

## Iteration history

1. Implemented the chosen light native direction in SwiftUI/AppKit and captured all three idle modes.
2. Compared the original concept and packaged Cleaning screen in one image, confirmed the functional state through the accessibility tree, and retained native system-control rendering for the two P3 differences above.
3. Rebuilt the universal application bundle, relaunched that exact bundle, and captured the final comparison evidence.
4. Replaced the conflicting dual-Command shortcut with a three-second Escape hold, reran the input-state tests, rebuilt the bundle, and recaptured the final native window.

## Final result

passed
