# External browser music — 2026-09-15

Background music no longer belongs in the browser core PCK. The existing
HTMLAudio bridge requests individual tracks from release `assetBaseUrl` storage
(R2 in the release design), or local `/browser-audio/` in the connected preview.
The local audio-copy and release-publication pipeline is unchanged. No bucket
or production mutation was made.

Removed the legacy embedded music preloads and excluded `assets/music/**` from
the core web preset. Native MusicManager loading and desktop presets are
unchanged. Effects/cries remain included, with their existing browser playback
transport also unchanged.

The builder now audits the actual unencrypted PCK directory, including imported
music resources found through source import metadata. It does not reject music
path strings used by the external playback code. An embedded music entry fails
the build rather than silently inflating the initial download.

Focused evidence:

- `web_audio_shell_check.gd`: PASS.
- `python3 -m unittest test_web_external_music` from `tools`: 2 tests PASS;
  covers PCK v2/v3, allowed effect resources, forbidden raw/imported music.
- The audit rejects the previous real pack and accepts the rebuilt pack.
- Initial preview: **300.9 → 261.6 MiB**, approximately **39.3 MiB less** before
  HTTP compression. The new pack retains 1,599 imported audio entries for
  effects/cries. Audio sources have not been deleted or modified.
- `web_external_music_smoke.cjs`: PASS with the real exported Godot build and
  public API/news stubs. Actual login music plays externally; a battle track
  plays through the browser bridge; an effect resource loads successfully.
  This does not play an actual battle or exercise a published R2 environment.

These are download/build-size measurements, not a total browser RAM/GPU
benchmark. The next memory optimization should use this revised baseline.
