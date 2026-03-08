# Analyzer Platform Animation — Concept & Implementation Plan

## The Idea (User's Vision)

When a user pastes a URL and presses **Analyze**, instead of immediately jumping to the Analyzed Screen with a boring loader:

1. A **platform detection interstitial** plays — a dark overlay fills the screen
2. In the center is a **glowing orb / logo** (the app icon), surrounded by **platform icons** (YouTube, Instagram, TikTok, Facebook, Vimeo, etc.) connected to the center by animated "data wire" lines
3. The URL is parsed in the background — when the platform is detected, the corresponding platform icon **brightens with a pulse glow** and the "wire" from center to that icon **animates energy flowing through it**
4. After platform detection, yt-dlp runs the fetch. As the fetch progresses, the animation continues — the wire from the platform logo **flows into a secondary check** (single video vs. playlist)
5. Two icons appear: a **single video icon** and a **playlist icon**. The correct one lights up.
6. Once metadata is ready, a **cinematic transition** (scale + fade) pushes the animation away and reveals the **correct Analyzed Screen** (different UI for YouTube single / playlist / audio-only / etc.)

---

## Why This is Great UX

> "Don't make users feel like they're waiting — make them feel like something is *happening*."

- yt-dlp fetch can take 2–5 seconds. Without animation: dead silence, spinner, feels broken.
- With this animation: the 2 seconds feel intentional and interesting.
- Users instantly learn **which platform was detected** — builds confidence.
- The "single vs. playlist" reveal is genuinely useful information users want to know.

---

## Screen Breakdown by Content Type

The current `AnalyzedScreen` is one-size-fits-all. After the animation redirects, it should go to a **specialized screen**:

| URL Type | Screen Name | Key Differences |
|----------|-------------|-----------------|
| YouTube single video | `YoutubeVideoScreen` | Current layout (thumbnail + quality tiles) |
| YouTube playlist | `YoutubePlaylistScreen` | Playlist thumbnail grid, select all/some, total size estimate |
| Instagram reel/post | `InstaReelScreen` | Square crop thumbnail, usually no quality choice (best only) |
| Instagram carousel | `InstaCarouselScreen` | Multi-item strip with checkboxes |
| TikTok | `TikTokScreen` | Similar to Instagram reel, watermark removal option |
| Audio-only (any) | `AudioScreen` | Waveform placeholder, bitrate selector only |
| Generic / fallback | `GenericVideoScreen` | Simplified layout, less metadata |

---

## Animation Architecture (Technical)

### State Machine

```
IDLE
  │ (user presses Analyze)
  ▼
DETECTING_PLATFORM
  │ URL parsed (instant, regex)
  ▼
FETCHING_METADATA  ← yt-dlp running
  │ platform known, streaming progress
  ▼
DETECTING_TYPE     (is it playlist? single?)
  │ metadata received
  ▼
TRANSITIONING_OUT  ← scale/fade animation
  │
  ▼
ANALYZED_SCREEN_SHOWN
```

### Animation Components

#### 1. Center Orb
- Dark circle, 80px diameter
- App icon or a generic "DT" logo
- Subtle continuous **pulse glow** (AnimationController, repeat, 1.5s cycle)
- On DETECTING_PLATFORM: glow intensifies

#### 2. Platform Icons Ring
- 6–8 platform icons arranged in a circle, radius ~140px
- Rendered using `CustomPainter` or `Stack` with `Positioned` + trigonometry
- Each icon: 40px, muted/desaturated until selected
- When the platform matches: `AnimatedScale(scale: 1.3)` + full color + glow shadow

#### 3. Wire / Energy Lines
- Drawn with `CustomPainter`, `Canvas.drawPath` with dashed stroke
- Each line from center to planet icon has a **shimmer dot** traveling along it (progress 0.0→1.0)
- On activation: the traveling dot brightens, speed increases, color changes to platform accent

#### 4. Type Detection Row (phase 2)
- After platform activates, a **second row** appears below the detected platform icon
- Contains: `VideocamIcon` (single) and `PlaylistIcon` (playlist)
- Connected by a short horizontal line from the platform icon downward
- The correct one activates with the same glow

#### 5. Background
- Very dark (matches app background `#060C08`)
- Faint grid pattern (same as `_GridPainter` in analyzed screen)
- Subtle radial glow from center matching platform color

---

## Implementation Plan

### Phase 1 — Interstitial widget scaffold

**New file**: `lib/screens/analyzer_interstitial.dart`

```dart
class AnalyzerInterstitial extends StatefulWidget {
  final String url;
  final VoidCallback onComplete; // called when fetch done → triggers transition
  const AnalyzerInterstitial({required this.url, required this.onComplete});
}
```

**AnimationControllers needed:**
- `_pulseCtrl`: looping 1.5s, Curves.easeInOut → center orb glow
- `_wireCtrl`: 0.8s per wire → the shimmer dot travel
- `_activateCtrl`: 0.5s → platform icon highlight
- `_transitionCtrl`: 0.6s → exit scale/fade

### Phase 2 — Platform detection logic

```dart
String _detectPlatform(String url) {
  if (url.contains('youtube.com') || url.contains('youtu.be')) return 'youtube';
  if (url.contains('instagram.com')) return 'instagram';
  if (url.contains('tiktok.com')) return 'tiktok';
  if (url.contains('facebook.com') || url.contains('fb.watch')) return 'facebook';
  if (url.contains('twitter.com') || url.contains('x.com')) return 'twitter';
  if (url.contains('vimeo.com')) return 'vimeo';
  return 'generic';
}
```

This runs *synchronously before* even calling yt-dlp, so the animation can start immediately.

### Phase 3 — Wire painter

```dart
class WirePainter extends CustomPainter {
  final List<Offset> planetPositions;
  final int activePlanet;           // -1 = none
  final double shimmerProgress;     // 0.0 → 1.0 for the traveling dot
  // ...
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (int i = 0; i < planetPositions.length; i++) {
      final active = i == activePlanet;
      _drawWire(canvas, center, planetPositions[i], active, shimmerProgress);
    }
  }
}
```

### Phase 4 — Navigation integration

Replace the current navigation in `app_shell.dart` where `_onAnalyze(url)` is called:

```dart
// Before: set _pendingUrl and navigate to analyzed screen directly
// After:
Navigator.of(context).push(PageRouteBuilder(
  opaque: false,
  pageBuilder: (_, __, ___) => AnalyzerInterstitial(
    url: url,
    onComplete: () {
      Navigator.pop(context);  // remove interstitial
      setState(() {
        _pendingUrl = url;
        _selectedIndex = 5;    // go to analyzed screen
      });
    },
  ),
  transitionDuration: Duration.zero,
));
```

The `AnalyzerInterstitial` calls `AppState.instance.fetchVideo(url)` itself, listens to `FetchState`, and calls `onComplete` when state becomes `success` or `error`.

### Phase 5 — Transition out

When `onComplete` fires:
- `_transitionCtrl.forward()` plays a scale-from-1 to scale-0.8 + fade out
- Once done, `Navigator.pop()` removes the overlay
- The Analyzed Screen underneath is already ready (Offstage lifted)

For a premium feel, pair with a `Hero` widget on the platform badge — it "flies" from the interstitial position into the analyzed screen header.

---

## Specialized Analyzed Screens (Future Sub-routes)

Once the animation resolves the type, pass a `contentType` enum to `AnalyzedScreen`:

```dart
enum ContentType {
  youtubeSingle,
  youtubePlaylist,
  instagramSingle,
  instagramCarousel,
  tiktok,
  audio,
  generic,
}
```

Each type shows a different `_buildVideoHeader()` variant:
- **Playlist**: shows thumbnail grid (first 4 thumbnails), item count, total estimated size
- **Instagram**: square crop, caption preview
- **Audio-only**: waveform placeholder, no quality tiles (only bitrate)

---

## Estimated Effort

| Phase | Effort | Difficulty |
|-------|--------|------------|
| 1: Scaffold widget | 1–2 hrs | Easy |
| 2: Platform detection | 30 min | Easy |
| 3: Wire painter | 3–4 hrs | Medium |
| 4: Navigation integration | 1 hr | Easy |
| 5: Transition out | 1–2 hrs | Medium |
| 6: Specialized screens | 4–6 hrs | Medium–Hard |
| **Total** | **~10–15 hrs** | **Medium** |

---

## My Thoughts

This is a genuinely great UX idea and technically very feasible. A few things to keep in mind:

**What makes it work:**
- The animation must finish or reach a "ready enough" state within the actual fetch time (~2–5s). Since yt-dlp runs in the background while the animation plays, there's no added wait time — the animation is **concurrent**, not sequential.
- Keep the animation **skippable** — if the user clicks/taps, it fast-forwards to the analyzed screen immediately. Power users will appreciate this.

**Pitfalls to avoid:**
- Don't make the wire/energy animation too slow. The shimmer dot traveling to each icon should take ≤ 0.8s each.
- If the fetch finishes before the animation "reaches" the type-detection phase, hold the animation at the platform highlight stage for a moment before auto-completing — don't abruptly skip.
- The interstitial should be a full-screen overlay (not a new route that pushes with a slide) — use `showGeneralDialog` or a `Stack` overlay so the background (app content) is still visible blurred underneath.

**The Hero transition:**
The platform badge appearing in the analyzed screen header is the perfect candidate for a `Hero` widget. The badge "arrives" from the center of the interstitial with a scale+position animation — this is the finishing touch that makes the whole sequence feel premium.
