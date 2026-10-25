# Marble Madness app

Flutter app for Android and iOS, built on the rules engine in
`packages/game_core`.

This first version plays a single-player game on one phone: you take the
blue seat and choose 1 to 4 computer opponents.

```sh
flutter pub get
flutter run      # on a connected phone or simulator
flutter test
```

- `lib/src/game_controller.dart` runs the game and the computer turns.
- `lib/src/board_geometry.dart` places the 108 track seats, Home and
  Destination spots on the hexagon.
- `lib/src/board_view.dart` draws the board; `lib/src/game_screen.dart` is
  the play screen with your hand and the moves for the chosen card.
