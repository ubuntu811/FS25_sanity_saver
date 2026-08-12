# FS25_sanity_saver

Fixed autosave for Farming Simulator 25. No more "never saved" or
"only saves when I open the menu."

Two tiers:

1. **Hard ceiling** - forces a save every 60 minutes, no matter what.
2. **Opportunistic AFK save** - once 45 minutes have passed without a
   save, it starts watching for a ~60s gap with no keyboard/mouse
   activity and sneaks a save into that gap instead of waiting out
   the full hour (or interrupting you mid-action).

Being in any menu counts as "active," so it never fights with a manual
save. Every autosave logs a line to `log.txt`.

Activity detection is keyboard/mouse based. A gamepad-only session
won't reset the idle timer, so it just degrades to a plain 60-minute
interval autosave for that case - still strictly better than never.

## Install

Drop `FS25_sanity_saver` into your FS25 mods folder like any other mod.
No dependencies, no config.

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

## Tuning

All three thresholds are constants at the top of `SanitySaver.lua`
(`SAVE_INTERVAL`, `WARMUP`, `AFK_THRESHOLD`) if 60/45/1 minutes isn't
your sweet spot.

## Build tooling

`build/build.sh` validates the Lua/XML and packages a zip;
`build/deploy.sh` rebuilds and drops a loose unzipped copy straight into
`~/fs25/mods/FS25_sanity_saver/` for FS25's hot-reload. Same pattern as
[FS25_whatAmILookingAt](https://github.com/ubuntu811/FS25_whatAmILookingAt).

## License

GPLv3 - see [LICENSE](LICENSE).
