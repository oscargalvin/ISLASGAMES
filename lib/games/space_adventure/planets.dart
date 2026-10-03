import 'dart:ui';

/// What happens when you press ENTER next to a planet.
enum LandingType {
  /// Earth: you get fixed up.
  home,

  /// You climb out and explore.
  walk,
}

class Planet {
  const Planet({
    required this.name,
    required this.position,
    required this.radius,
    required this.color,
    this.landing = LandingType.walk,
  });

  final String name;
  final Offset position;
  final double radius;
  final Color color;
  final LandingType landing;

  /// "the Moon" reads better than "Moon" in sentences.
  String get title => name == 'Moon' ? 'the Moon' : name;
}

/// The Sun sits in the middle of the map at (0, 0).
const sunRadius = 160.0;
const sunColor = Color(0xFFFFC107);

/// Planets in order, going out from the Sun. Not to scale - space is BIG!
const planets = <Planet>[
  Planet(
      name: 'Mercury',
      position: Offset(750, -160),
      radius: 16,
      color: Color(0xFF9C9087)),
  Planet(
      name: 'Venus',
      position: Offset(1050, 190),
      radius: 26,
      color: Color(0xFFE8C98E)),
  Planet(
      name: 'Earth',
      position: Offset(1500, 0),
      radius: 30,
      color: Color(0xFF1E5FB4),
      landing: LandingType.home),
  Planet(
      name: 'Moon',
      position: Offset(1680, -90),
      radius: 12,
      color: Color(0xFFB8B8B8)),
  Planet(
      name: 'Mars',
      position: Offset(2150, 130),
      radius: 20,
      color: Color(0xFFC1502A)),
  Planet(
      name: 'Jupiter',
      position: Offset(3100, -200),
      radius: 70,
      color: Color(0xFFD8B48A)),
  Planet(
      name: 'Saturn',
      position: Offset(3900, 230),
      radius: 58,
      color: Color(0xFFE3CC98)),
  Planet(
      name: 'Uranus',
      position: Offset(4650, -160),
      radius: 40,
      color: Color(0xFF9FE0E6)),
  Planet(
      name: 'Neptune',
      position: Offset(5400, 170),
      radius: 38,
      color: Color(0xFF3B63D6)),
  Planet(
      name: 'Pluto',
      position: Offset(6200, -60),
      radius: 11,
      color: Color(0xFFD9C3A8)),
];

Planet planetNamed(String name) => planets.firstWhere((p) => p.name == name);

/// How the ground looks.
enum GroundStyle { rock, lava, ice, cloud }

/// How the planet makes you feel - picks the warning messages.
enum Feel { fine, hot, cold, sick }

/// What it's like to stand on each planet.
class SurfaceInfo {
  const SurfaceInfo({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.ground,
    required this.groundDark,
    required this.mountains,
    required this.style,
    required this.gravity,
    required this.itemName,
    required this.itemColor,
    required this.landmark,
    required this.fact,
    required this.feel,
    required this.drain,
    required this.temperature,
    required this.deathReason,
    this.calmStatus = 'Exploring... use the arrow keys!',
    this.haze = const Color(0x00000000),
    this.starAlpha = 0,
    this.sunSize = 0,
    this.skyObject = '',
  });

  final Color skyTop, skyMid, skyBottom;
  final Color ground, groundDark, mountains;
  final GroundStyle style;
  final double gravity;
  final String itemName;
  final Color itemColor;

  /// flag, rover, volcano, crater, heart, storm or '' for nothing.
  final String landmark;
  final String fact;
  final Feel feel;

  /// Health lost per second when you first land. It goes up the longer you stay.
  final double drain;

  /// -1 freezing ... 1 boiling (for the thermometer).
  final double temperature;
  final String deathReason;
  final String calmStatus;
  final Color haze;
  final double starAlpha;
  final double sunSize;

  /// earth, phobos, rings, tiltedRings, charon or ''.
  final String skyObject;
}

const surfaces = <String, SurfaceInfo>{
  'Mercury': SurfaceInfo(
    skyTop: Color(0xFF000000),
    skyMid: Color(0xFF040406),
    skyBottom: Color(0xFF15121A),
    ground: Color(0xFF8C8178),
    groundDark: Color(0xFF4A433E),
    mountains: Color(0xFF5E5650),
    style: GroundStyle.rock,
    gravity: 380,
    itemName: 'metal nugget',
    itemColor: Color(0xFFCFD8DC),
    landmark: 'crater',
    fact:
        'Mercury has no air, so the Sun looks HUGE and the days are hotter than an oven!',
    feel: Feel.hot,
    drain: 2.0,
    temperature: 0.85,
    deathReason: 'You stayed on boiling-hot Mercury for too long! 🔥',
    starAlpha: 1,
    sunSize: 90,
  ),
  'Venus': SurfaceInfo(
    skyTop: Color(0xFF7A3E10),
    skyMid: Color(0xFFC07228),
    skyBottom: Color(0xFFEDB25C),
    ground: Color(0xFF5C3B29),
    groundDark: Color(0xFF2A1A12),
    mountains: Color(0xFF8A5530),
    style: GroundStyle.lava,
    gravity: 880,
    itemName: 'volcano crystal',
    itemColor: Color(0xFFFF8A50),
    landmark: 'volcano',
    fact:
        'Venus has thousands of volcanoes, and its thick clouds trap the heat like a giant blanket!',
    feel: Feel.hot,
    drain: 3.0,
    temperature: 1.0,
    deathReason: 'You stayed on Venus for too long - it was way too hot! 🔥',
    haze: Color(0x66F2A346),
  ),
  'Moon': SurfaceInfo(
    skyTop: Color(0xFF000000),
    skyMid: Color(0xFF000000),
    skyBottom: Color(0xFF0B0B12),
    ground: Color(0xFFABABAB),
    groundDark: Color(0xFF5C5C60),
    mountains: Color(0xFF7D7D82),
    style: GroundStyle.rock,
    gravity: 260,
    itemName: 'Moon rock',
    itemColor: Color(0xFFE0E0E0),
    landmark: 'flag',
    fact:
        'Astronauts first walked on the Moon in 1969. Their footprints are still here!',
    feel: Feel.fine,
    drain: 0.2,
    temperature: -0.1,
    deathReason: 'You stayed out on the Moon so long your oxygen ran out! 💨',
    calmStatus: 'Bouncy low gravity! Press UP to do a giant jump!',
    starAlpha: 1,
    sunSize: 22,
    skyObject: 'earth',
  ),
  'Mars': SurfaceInfo(
    skyTop: Color(0xFFA9765A),
    skyMid: Color(0xFFD3A07A),
    skyBottom: Color(0xFFE8C4A0),
    ground: Color(0xFFB4562D),
    groundDark: Color(0xFF6A2C16),
    mountains: Color(0xFF9C5838),
    style: GroundStyle.rock,
    gravity: 380,
    itemName: 'red Mars rock',
    itemColor: Color(0xFFFF7043),
    landmark: 'rover',
    fact:
        'Mars is red because its dust is rusty! Robot rovers drive around here taking photos.',
    feel: Feel.fine,
    drain: 0.3,
    temperature: -0.4,
    deathReason: 'You stayed out on Mars so long your oxygen ran out! 💨',
    calmStatus: 'A bit chilly, but your space suit keeps you warm.',
    haze: Color(0x40E2B08A),
    sunSize: 11,
    skyObject: 'phobos',
  ),
  'Jupiter': SurfaceInfo(
    skyTop: Color(0xFF231810),
    skyMid: Color(0xFF8A6844),
    skyBottom: Color(0xFFD9BA8C),
    ground: Color(0xFFEBD6B2),
    groundDark: Color(0xFFAD875B),
    mountains: Color(0xFFC49A69),
    style: GroundStyle.cloud,
    gravity: 1000,
    itemName: 'ammonia ice crystal',
    itemColor: Color(0xFFFFF3E0),
    landmark: 'storm',
    fact:
        'Jupiter is made of gas - you are on a hover-board above the clouds! The Great Red Spot is a storm bigger than Earth!',
    feel: Feel.sick,
    drain: 1.2,
    temperature: -0.6,
    deathReason: "Jupiter's radiation made you too sick! 🤢",
    starAlpha: 0.25,
    sunSize: 6,
    haze: Color(0x30D9BA8C),
  ),
  'Saturn': SurfaceInfo(
    skyTop: Color(0xFF16151F),
    skyMid: Color(0xFF7A6B4F),
    skyBottom: Color(0xFFE2D1A5),
    ground: Color(0xFFF0E2BD),
    groundDark: Color(0xFFBFA574),
    mountains: Color(0xFFD6BF8E),
    style: GroundStyle.cloud,
    gravity: 900,
    itemName: 'ring ice chunk',
    itemColor: Color(0xFFE0F7FA),
    landmark: '',
    fact:
        "Saturn is made of gas, so you're hovering over the clouds. Its rings are made of billions of chunks of ice!",
    feel: Feel.cold,
    drain: 0.7,
    temperature: -0.7,
    deathReason: 'You stayed above freezing Saturn for too long! 🥶',
    starAlpha: 0.5,
    sunSize: 5,
    skyObject: 'rings',
  ),
  'Uranus': SurfaceInfo(
    skyTop: Color(0xFF0A2730),
    skyMid: Color(0xFF3C8796),
    skyBottom: Color(0xFF9CDCE0),
    ground: Color(0xFFC3EFF0),
    groundDark: Color(0xFF6DB3BC),
    mountains: Color(0xFF8BCDD4),
    style: GroundStyle.cloud,
    gravity: 800,
    itemName: 'ice gem',
    itemColor: Color(0xFF80DEEA),
    landmark: '',
    fact: 'Uranus spins on its side, like a ball rolling around the Sun!',
    feel: Feel.cold,
    drain: 0.9,
    temperature: -0.85,
    deathReason: 'You stayed above icy Uranus for too long! 🥶',
    starAlpha: 0.4,
    sunSize: 4,
    skyObject: 'tiltedRings',
  ),
  'Neptune': SurfaceInfo(
    skyTop: Color(0xFF040A28),
    skyMid: Color(0xFF1B3A96),
    skyBottom: Color(0xFF4F7DDC),
    ground: Color(0xFF7097EC),
    groundDark: Color(0xFF2A49AC),
    mountains: Color(0xFF3E66CA),
    style: GroundStyle.cloud,
    gravity: 950,
    itemName: 'space diamond',
    itemColor: Color(0xFFE1F5FE),
    landmark: 'storm',
    fact:
        'Neptune has the fastest winds in the solar system - and scientists think it might rain diamonds deep inside!',
    feel: Feel.cold,
    drain: 1.1,
    temperature: -0.9,
    deathReason: 'You stayed in the freezing winds of Neptune for too long! 🌪️',
    starAlpha: 0.35,
    sunSize: 3,
  ),
  'Pluto': SurfaceInfo(
    skyTop: Color(0xFF000000),
    skyMid: Color(0xFF04060D),
    skyBottom: Color(0xFF1A2340),
    ground: Color(0xFFE4D3C0),
    groundDark: Color(0xFF8E7562),
    mountains: Color(0xFFC6D4E6),
    style: GroundStyle.ice,
    gravity: 200,
    itemName: 'ice crystal',
    itemColor: Color(0xFF81D4FA),
    landmark: 'heart',
    fact:
        'Pluto has a giant heart-shaped patch of ice, and mountains made of frozen water!',
    feel: Feel.cold,
    drain: 1.0,
    temperature: -1.0,
    deathReason: 'You stayed on icy Pluto for too long and froze! 🥶',
    starAlpha: 1,
    sunSize: 3,
    skyObject: 'charon',
  ),
};

/// The warning messages, from "a bit" to "get out NOW".
List<String> feelMessages(SurfaceInfo info) {
  switch (info.feel) {
    case Feel.hot:
      return const [
        "It's getting a bit hot here... 🥵",
        "It's getting REALLY hot! Don't stay too long! 🥵",
        'WAY too hot! Get back to your rocket NOW! 🔥',
      ];
    case Feel.cold:
      return const [
        "It's getting a bit cold here... 🥶",
        "Brrr! You're getting really cold! 🥶",
        'FREEZING! Get back to your rocket NOW! 🥶',
      ];
    case Feel.sick:
      return const [
        'The radiation here is making you feel a bit sick... 🤢',
        "You're feeling really sick! Don't stay too long! 🤢",
        'Too much radiation! Get back to your rocket NOW! ☢️',
      ];
    case Feel.fine:
      return [
        info.calmStatus,
        info.calmStatus,
        "You've been out a long time - your oxygen is getting low! 💨",
      ];
  }
}
