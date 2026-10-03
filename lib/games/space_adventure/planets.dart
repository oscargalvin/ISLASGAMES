import 'dart:ui';

/// What happens when you press ENTER next to a planet.
enum LandingType {
  /// Earth: you get fixed up.
  home,

  /// You can climb out and walk around.
  walk,

  /// Far too hot - you get hurt and blast straight back off.
  tooHot,

  /// Made of gas - nothing to stand on.
  gas,
}

class Planet {
  const Planet({
    required this.name,
    required this.position,
    required this.radius,
    required this.color,
    required this.landing,
    this.ringColor,
    this.banded = false,
    this.landingMessage = '',
    this.landingDamage = 0,
    this.deathReason = '',
  });

  final String name;
  final Offset position;
  final double radius;
  final Color color;
  final LandingType landing;
  final Color? ringColor;
  final bool banded;
  final String landingMessage;
  final double landingDamage;
  final String deathReason;

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
    color: Color(0xFF9E9E9E),
    landing: LandingType.tooHot,
    landingMessage: 'OUCH! Mercury is SIZZLING hot!\nGet me off of here!',
    landingDamage: 25,
    deathReason: 'Mercury was far too hot to land on! 🔥',
  ),
  Planet(
    name: 'Venus',
    position: Offset(1050, 190),
    radius: 26,
    color: Color(0xFFFFCC80),
    landing: LandingType.tooHot,
    landingMessage: "Oh, that's HOT!\nGet me off of here!",
    landingDamage: 35,
    deathReason: 'Venus was way too hot! 🔥',
  ),
  Planet(
    name: 'Earth',
    position: Offset(1500, 0),
    radius: 30,
    color: Color(0xFF1E88E5),
    landing: LandingType.home,
  ),
  Planet(
    name: 'Moon',
    position: Offset(1680, -90),
    radius: 12,
    color: Color(0xFFBDBDBD),
    landing: LandingType.walk,
  ),
  Planet(
    name: 'Mars',
    position: Offset(2150, 130),
    radius: 20,
    color: Color(0xFFE64A19),
    landing: LandingType.walk,
  ),
  Planet(
    name: 'Jupiter',
    position: Offset(3100, -200),
    radius: 70,
    color: Color(0xFFD7A86E),
    banded: true,
    landing: LandingType.gas,
    landingMessage:
        "Whoa! Jupiter is made of gas - there's nothing to stand on!\nAnd the radiation is making me feel sick! 🤢",
    landingDamage: 15,
    deathReason: "Jupiter's radiation made you too sick! 🤢",
  ),
  Planet(
    name: 'Saturn',
    position: Offset(3900, 230),
    radius: 58,
    color: Color(0xFFE6C88A),
    ringColor: Color(0xFFCDB58A),
    banded: true,
    landing: LandingType.gas,
    landingMessage:
        "Saturn is made of gas, so I can't land here...\nbut WOW, look at those rings! 💍",
  ),
  Planet(
    name: 'Uranus',
    position: Offset(4650, -160),
    radius: 40,
    color: Color(0xFF80DEEA),
    ringColor: Color(0x6680DEEA),
    landing: LandingType.gas,
    landingMessage:
        'Brrr! Uranus is a giant icy ball of gas.\nNowhere to land! 🥶',
    landingDamage: 5,
    deathReason: 'Uranus was too icy cold! 🥶',
  ),
  Planet(
    name: 'Neptune',
    position: Offset(5400, 170),
    radius: 38,
    color: Color(0xFF3F51B5),
    landing: LandingType.gas,
    landingMessage:
        'Neptune has the fastest winds in the solar system!\nWHOOSH! Get me out of here! 🌪️',
    landingDamage: 10,
    deathReason: 'The winds on Neptune blew you away! 🌪️',
  ),
  Planet(
    name: 'Pluto',
    position: Offset(6200, -60),
    radius: 11,
    color: Color(0xFFD7CCC8),
    landing: LandingType.walk,
  ),
];

Planet planetNamed(String name) => planets.firstWhere((p) => p.name == name);

/// What the ground looks and feels like on the planets you can walk on.
class SurfaceInfo {
  const SurfaceInfo({
    required this.skyTop,
    required this.skyBottom,
    required this.ground,
    required this.gravity,
    required this.itemName,
    required this.itemColor,
    required this.landmark,
    required this.landmarkFact,
    required this.status,
    this.temperature = 0,
    this.coldDrain = 0,
    this.coldReason = '',
    this.showStars = true,
    this.showEarth = false,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color ground;
  final double gravity;
  final String itemName;
  final Color itemColor;
  final String landmark;
  final String landmarkFact;
  final String status;
  final double temperature;
  final double coldDrain;
  final String coldReason;
  final bool showStars;
  final bool showEarth;
}

const surfaces = <String, SurfaceInfo>{
  'Moon': SurfaceInfo(
    skyTop: Color(0xFF000000),
    skyBottom: Color(0xFF1A1A2E),
    ground: Color(0xFFB0B0B0),
    gravity: 260,
    itemName: 'Moon rock',
    itemColor: Color(0xFFE0E0E0),
    landmark: 'flag',
    landmarkFact:
        'Astronauts first walked on the Moon in 1969. Their footprints are still here!',
    status: 'Bouncy low gravity! Press UP to do a giant jump!',
    temperature: -0.2,
    showEarth: true,
  ),
  'Mars': SurfaceInfo(
    skyTop: Color(0xFFBF6F4A),
    skyBottom: Color(0xFFE8A87C),
    ground: Color(0xFFC1440E),
    gravity: 600,
    itemName: 'red Mars rock',
    itemColor: Color(0xFFFF7043),
    landmark: 'rover',
    landmarkFact:
        'Robot rovers drive around Mars taking photos and testing the rocks!',
    status: 'A bit chilly, but your space suit keeps you warm.',
    temperature: -0.35,
    showStars: false,
  ),
  'Pluto': SurfaceInfo(
    skyTop: Color(0xFF000000),
    skyBottom: Color(0xFF0D1B3E),
    ground: Color(0xFFE8DCCF),
    gravity: 200,
    itemName: 'ice crystal',
    itemColor: Color(0xFF81D4FA),
    landmark: 'heart',
    landmarkFact: 'Pluto has a giant heart-shaped patch of ice!',
    status: "Brrr! It's FREEZING on Pluto - don't stay too long!",
    temperature: -0.9,
    coldDrain: 1.5,
    coldReason: 'You froze on icy Pluto! 🥶',
  ),
};
