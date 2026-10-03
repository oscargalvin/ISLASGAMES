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
1. **Get your rocket ready.** Tap each job and watch your astronaut walk over and do it: fill the fuel from the truck, carry the oxygen and snacks on board, change into a space suit, fix the engines, then ride the lift up and close the hatch. Press **LAUNCH** (or ENTER).
2. **Blast off.** The trip to space says 5 minutes, but it only takes 50 seconds. Steer with ⬅️ ➡️.
3. **Explore the solar system.** Fly with the arrow keys. When you reach a planet, press **ENTER** to land, or keep flying to skip it. You can explore **every** planet. Walk with the arrow keys, press UP to jump for the glowing gems, and press ENTER to blast off again. On the gas planets you ride a hover-board above the clouds.
4. **Stay alive.**
   - Being in space wears your health down a tiny bit all the time.
   - Small warnings pop up when you're getting hot, cold, sick or hurt.
   - On a planet, the longer you stay, the faster your health drops. Venus and Mercury are the worst!
   - Land on Earth to get fixed up. If your health runs out, the whole game starts again from the launch pad.
5. Visit every planet out to Pluto to win! 🏆

## Adding a game

1. Build your game as a widget (see `TapCounterGame` in `lib/screens/home_screen.dart`).
2. Add a `GameEntry` for it to the `games` list — it appears on the home screen.

## Tests

```bash
flutter test
```
