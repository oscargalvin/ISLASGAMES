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

## Adding a game

1. Build your game as a widget (see `TapCounterGame` in `lib/screens/home_screen.dart`).
2. Add a `GameEntry` for it to the `games` list — it appears on the home screen.

## Tests

```bash
flutter test
```
