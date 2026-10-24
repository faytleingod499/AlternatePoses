# Alternate Poses

An addon for [Hugs and More](https://github.com/faytleingod499/HugsAndMore) (1.3.0 or newer, required) that adds more
two-player emotes to its **F** menu: **side hug**, **hold hands**, **fist bump**, **twirl** and **bow**.

*This mod was created with the assistance of AI.*

Both players need Hugs and More and Alternate Poses. Walk up to a player who has them: the **F  Interact** tag appears, F opens
the menu, and they say yes with **Y** or the button. Works on any server.

## How it works
- Hugs and More publishes itself as the root meta `hugsandmore_api`. This mod finds it and calls `register_emote(id, def)` for
  each emote, with the method that draws it (`pose_<name>(p, hugs)`), a lobby key it needs the other player to have
  (`alternateposes_v`) and the label / invitation texts. Hugs and More does the invitation, the lobby sync and the timing.
- Each pose is drawn on both players with bone overrides through Hugs and More's helpers (`_place_body`, `_reach`,
  `_tilt_head_toward`, ...). Nobody's real position changes. Side by side poses work out which way they face once, when they start,
  and stand where each player already was.
- The mod announces itself in the Steam lobby member data `alternateposes_v` (rechecked every 3 s), so the others only offer
  these emotes to players who have it.
- Adding an emote: an entry in `EMOTES` / `ORDER` and a `pose_<name>` method.

## Building
`source/mods/AlternatePoses/` holds the script; `pack.gd` packs the `.pck` with Godot 3.5 (it has a fixed file list):

```
godot --no-window -s pack.gd
./build.sh
```

`build.sh` makes `out/AlternatePoses-mod.zip` (the folder for `GDWeave/mods`) and the Thunderstore upload zip. Requires
[GDWeave](https://thunderstore.io/c/webfishing/p/NotNet/GDWeave/) and Hugs and More.

## License

[MIT](LICENSE).
