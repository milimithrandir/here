# Here ◌

A tiny macOS menu-bar app that, at random moments, asks you: **are you here?**

Inspired by Osho's (and Gurdjieff's) *self-remembering*: suddenly becoming aware that you are alive, right now. Every 8–44 minutes (about every 25 on average, never on a rhythm), something gentle and different appears on your screen. Notice it, take a breath, click it away.

It's never the same twice. There are 14 kinds of moments:

- **Subtle:** a single word, a two-part question, a glow around the screen's edges, ripples from your cursor, a halo that follows your cursor, a heartbeat dot
- **Medium:** a breathing orb, an ink drop, a dawn rising from the bottom of the screen, a frosted stillness
- **Catch it:** a firefly that wanders the screen, a falling petal
- **Rare:** a full-screen colour bloom, a night sky with a shooting star

Each moment gets a random palette and font. Words show up only sometimes and are always short ("Here.", "Who is seeing?", "Right now / you are alive."). There's no sound.

It waits while you're away or your screen is locked. A moment you ignore fades out after 3 minutes.

## Install

1. Download **Here.zip** from [Releases](../../releases/latest) and unzip it.
2. Move **Here.app** to Applications.
3. The app isn't notarized, so macOS blocks it the first time. Double-click it, close the warning, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. On macOS 14 you can instead **right-click → Open → Open**.
4. Look for ◌ in your menu bar. From there you can:
   - see how many times you were awake today
   - show a moment now, or try a specific one
   - pause for an hour or until tomorrow
   - turn on **Open at login**

Requires macOS 14 or later. Works on Apple Silicon and Intel.

## Build from source

```bash
./build.sh               # builds and installs to ~/Applications
./build.sh --no-install  # only builds dist/Here.zip
```

You only need the Xcode Command Line Tools. All the code is in `Sources/`; the moments live in `Moments.swift`.

## License

MIT
