# Islas Games

Building fun games, in Flutter.

## First-time setup

The platform folders (android/, ios/, web/, etc.) aren't committed yet. Generate them once:

```bash
flutter create . --project-name islas_games --org com.islasgames
flutter pub get
flutter run
```

`flutter create .` won't overwrite `lib/main.dart` or the other existing files.

## Games

### 🚀 Space Adventure
1. **Get your rocket ready.** Tick off every job on the checklist, then press **LAUNCH** (or ENTER).
2. **Blast off.** The trip to space says 5 minutes, but it only takes 50 seconds. Steer with ⬅️ ➡️.
3. **Explore the solar system.** Fly with the arrow keys. When you reach a planet, press **ENTER** to land, or keep flying to skip it.
   - **Moon, Mars, Pluto:** climb out and walk around with the arrow keys. Press UP to jump and collect the glowing gems, then press ENTER to blast off again.
   - **Mercury and Venus:** far too hot! You get hurt and fly straight back off.
   - **Jupiter, Saturn, Uranus, Neptune:** made of gas, so there's nowhere to land.
   - **Earth:** land here to get your health back.
4. **Stay alive.** Watch the bars. You get hot near the Sun, freezing far away, sick from Jupiter's radiation, and hurt by the asteroid belt. If your health runs out, the whole game starts again from the launch pad.
5. Visit every planet out to Pluto to win! 🏆

## Adding a game

1. Build your game as a widget (see `TapCounterGame` in `lib/screens/home_screen.dart`).
2. Add a `GameEntry` for it to the `games` list — it appears on the home screen.

## Tests

```bash
flutter test
```
