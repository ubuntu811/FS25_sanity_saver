# FS25_sanity_saver

Fixed autosave for Farming Simulator 25. No more "never saved" or
"only saves when I open the menu."

Two tiers:

1. **Hard ceiling** - forces a save every interval (60 min by default),
   no matter what.
2. **Opportunistic AFK save** - once 75% of that interval has passed
   without a save, it starts watching for a ~60s gap with no
   keyboard/mouse activity and sneaks a save into that gap instead of
   waiting out the full interval (or interrupting you mid-action).

Plus two saves triggered by real game events, not polling:

- **Sleeping** (day change) always saves - a deliberate, always-foreground
  action, so unlike the two timer-based tiers it can't be starved by the
  window being minimized (see Limitations).
- Any **completed save**, from any source (manual pause-menu save,
  another mod's quicksave, us) resets both internal timers - a manual
  save is never immediately followed by a redundant autosave.

Being in any menu counts as "active," so it never fights with a manual
save in progress. Every autosave logs a line to `log.txt`.

Activity detection is keyboard/mouse based. A gamepad-only session
won't reset the idle timer, so it just degrades to a plain interval
autosave for that case - still strictly better than never.

## Limitations

The engine doesn't call any mod code at all while the game window is
genuinely minimized/unfocused - confirmed via `scriptBinding.xml`
(no window-focus API exposed to Lua), and via live testing (a ~3 hour
minimized session correctly saved the instant focus returned, not at
any point during the 3 hours). This means the AFK/interval tiers can
only ever fire the moment the window becomes active again - not
genuinely *while* backgrounded. Sleep is unaffected (it requires the
window focused to trigger at all). In practice this is close to moot:
nothing is running to lose progress while the window is truly
suspended either.

## Install

Drop `FS25_sanity_saver` into your FS25 mods folder like any other mod.
No dependencies.

## Testing / debug

Waiting up to an hour to see it fire is not a fun dev loop. With the
in-game console enabled (`-cheats` launch option, `<controls>true</controls>`
in your game config), run:

```
sanitySaverDebugSkipWarmup
```

then close the console. Both internal timers get backdated past their
thresholds, so the very next update tick (once no menu/console is open)
should trigger a save immediately - confirms the whole chain end to end
without actually waiting.

## Config

Persistent, cross-save preference (not tied to any one savegame) at
`modSettings/FS25_sanity_saver/config.xml` - same pattern
[FS25_ImmersiveWeathering](https://github.com/ubuntu811/FS25_ImmersiveWeathering)
uses for its own settings. Two in-game console commands, both persist
immediately:

```
sanitySaverToggle              -- enable/disable entirely
sanitySaverSetInterval 30      -- change the hard-ceiling interval (minutes)
```

Handy if you're developing mods that might trash the world and want
autosave off for a while, without editing files.

The AFK-window watch (75%) and the 60s AFK threshold are constants at
the top of `SanitySaver.lua` (`WARMUP_FACTOR`, `AFK_THRESHOLD`) if
those need tuning too.

## Build tooling

`build/build.sh` validates the Lua/XML and packages a zip;
`build/deploy.sh` rebuilds and drops a loose unzipped copy straight into
`~/fs25/mods/FS25_sanity_saver/` for FS25's hot-reload. Same pattern as
[FS25_whatAmILookingAt](https://github.com/ubuntu811/FS25_whatAmILookingAt).

## License

GPLv3 - see [LICENSE](LICENSE).
