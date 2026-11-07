import 'dart:math' as math;

/// A stop on the way from Liverpool to Australia.
class City {
  const City(this.name, this.country, this.flag, this.lat, this.lon,
      {this.prices = 1.0, this.boatToNext = 0});

  final String name;
  final String country;
  final String flag;
  final double lat;
  final double lon;

  /// How expensive things are here compared to the UK (1.0).
  final double prices;

  /// If the next leg is over the sea, what the boat costs (in pounds).
  final int boatToNext;
}

const route = <City>[
  City('Liverpool', 'England', '🇬🇧', 53.41, -2.98),
  City('Birmingham', 'England', '🇬🇧', 52.49, -1.89),
  City('London', 'England', '🇬🇧', 51.51, -0.13),
  City('Dover', 'England', '🇬🇧', 51.13, 1.31, boatToNext: 35),
  City('Calais', 'France', '🇫🇷', 50.95, 1.86),
  City('Paris', 'France', '🇫🇷', 48.86, 2.35),
  City('Strasbourg', 'France', '🇫🇷', 48.57, 7.75),
  City('Munich', 'Germany', '🇩🇪', 48.14, 11.58),
  City('Vienna', 'Austria', '🇦🇹', 48.21, 16.37),
  City('Budapest', 'Hungary', '🇭🇺', 47.50, 19.04, prices: 0.7),
  City('Belgrade', 'Serbia', '🇷🇸', 44.79, 20.45, prices: 0.6),
  City('Sofia', 'Bulgaria', '🇧🇬', 42.70, 23.32, prices: 0.6),
  City('Istanbul', 'Turkey', '🇹🇷', 41.01, 28.98, prices: 0.6),
  City('Ankara', 'Turkey', '🇹🇷', 39.93, 32.86, prices: 0.5),
  City('Erzurum', 'Turkey', '🇹🇷', 39.90, 41.27, prices: 0.5),
  City('Tabriz', 'Iran', '🇮🇷', 38.08, 46.29, prices: 0.4),
  City('Tehran', 'Iran', '🇮🇷', 35.69, 51.39, prices: 0.4),
  City('Mashhad', 'Iran', '🇮🇷', 36.30, 59.60, prices: 0.4),
  City('Quetta', 'Pakistan', '🇵🇰', 30.18, 66.98, prices: 0.3),
  City('Lahore', 'Pakistan', '🇵🇰', 31.55, 74.34, prices: 0.3),
  City('Delhi', 'India', '🇮🇳', 28.61, 77.21, prices: 0.3),
  City('Kolkata', 'India', '🇮🇳', 22.57, 88.36, prices: 0.3),
  City('Dhaka', 'Bangladesh', '🇧🇩', 23.81, 90.41, prices: 0.3),
  City('Yangon', 'Myanmar', '🇲🇲', 16.84, 96.17, prices: 0.3),
  City('Bangkok', 'Thailand', '🇹🇭', 13.76, 100.50, prices: 0.4),
  City('Kuala Lumpur', 'Malaysia', '🇲🇾', 3.14, 101.69, prices: 0.4),
  City('Singapore', 'Singapore', '🇸🇬', 1.35, 103.82,
      prices: 0.9, boatToNext: 50),
  City('Jakarta', 'Indonesia', '🇮🇩', -6.21, 106.85, prices: 0.35),
  City('Bali', 'Indonesia', '🇮🇩', -8.65, 115.22,
      prices: 0.4, boatToNext: 180),
  City('Darwin', 'Australia', '🇦🇺', -12.46, 130.84, prices: 1.2),
  City('Alice Springs', 'Australia', '🇦🇺', -23.70, 133.88, prices: 1.2),
  City('Sydney', 'Australia', '🇦🇺', -33.87, 151.21, prices: 1.2),
];

/// Kilometres along roads between two cities (a bit more than a straight
/// line, because roads wiggle).
double legKm(City a, City b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) *
          math.cos(rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  final straight = 2 * r * math.asin(math.sqrt(h));
  return (straight * (a.boatToNext > 0 ? 1.0 : 1.25)).roundToDouble();
}

/// Kilometres from Liverpool to each city.
final List<double> cityKm = () {
  final out = <double>[0];
  for (var i = 1; i < route.length; i++) {
    out.add(out.last + legKm(route[i - 1], route[i]));
  }
  return out;
}();

double get totalKm => cityKm.last;

class Vehicle {
  const Vehicle(this.name, this.emoji, this.kmPerDay, this.tiring);

  final String name;
  final String emoji;
  final int kmPerDay;

  /// How much energy a day of travelling uses.
  final int tiring;
}

const vehicles = <Vehicle>[
  Vehicle('Walking', '🚶', 30, 35),
  Vehicle("Kid's bike", '🚲', 60, 32),
  Vehicle('Electric scooter', '🛴', 100, 22),
  Vehicle('Electric bike', '🚴', 150, 22),
  Vehicle('Moped', '🛵', 250, 16),
  Vehicle('Motorbike', '🏍️', 400, 16),
  Vehicle('Car', '🚗', 600, 12),
  Vehicle('Campervan', '🚐', 700, 10),
];

/// You get a new vehicle every this many days.
const daysPerVehicle = 14;

/// You get pocket money every this many days.
const daysPerMonth = 30;
const monthlyMoney = 800;

class Friend {
  Friend(this.name, this.city, this.flag);

  final String name;
  final String city;
  final String flag;

  Map<String, dynamic> toJson() => {'n': name, 'c': city, 'f': flag};
  static Friend fromJson(Map<String, dynamic> j) =>
      Friend(j['n'] as String, j['c'] as String, j['f'] as String);
}

const _friendNames = [
  'Amira',
  'Ben',
  'Chloé',
  'Dev',
  'Elif',
  'Farah',
  'Giorgio',
  'Hana',
  'Ivan',
  'Jaya',
  'Kai',
  'Lena',
  'Mo',
  'Nadia',
  'Omar',
  'Priya',
  'Quinn',
  'Rosa',
  'Sami',
  'Tom',
  'Uma',
  'Vik',
  'Wen',
  'Yusuf',
  'Zara',
];

enum Phase { morning, evening, won, lost }

enum Sleep { hotel, hostel, camp, campervan }

/// The whole survival trip: where you are, your money and how you feel.
class WalkGame {
  WalkGame();

  int day = 1;
  int money = monthlyMoney;
  int health = 100;
  int food = 80;
  int water = 80;
  int energy = 100;
  double km = 0;
  final List<Friend> friends = [];
  final List<String> log = [
    "Day 1: You set off from Liverpool! Next stop: Birmingham."
  ];
  bool saidHelloToday = false;
  Phase phase = Phase.morning;

  /// Something exciting to show in a pop-up (a new vehicle, payday...).
  String? news;

  Vehicle get vehicle =>
      vehicles[math.min((day - 1) ~/ daysPerVehicle, vehicles.length - 1)];
  int get daysToNextVehicle {
    final i = (day - 1) ~/ daysPerVehicle;
    if (i >= vehicles.length - 1) return 0;
    return (i + 1) * daysPerVehicle + 1 - day;
  }

  int get month => (day - 1) ~/ daysPerMonth + 1;
  int get daysToPayday => month * daysPerMonth + 1 - day;
  double get progress => (km / totalKm).clamp(0.0, 1.0);

  /// The last city you passed.
  int get cityIndex {
    var i = 0;
    while (i < route.length - 1 && cityKm[i + 1] <= km + 0.001) {
      i++;
    }
    return i;
  }

  City get here => route[cityIndex];
  City? get next => cityIndex < route.length - 1 ? route[cityIndex + 1] : null;
  double get kmToNext => next == null ? 0 : cityKm[cityIndex + 1] - km;

  /// True when you're at a port and the next leg is by boat.
  bool get atPort => here.boatToNext > 0 && km >= cityKm[cityIndex] - 0.001;

  int price(int pounds) => math.max(1, (pounds * here.prices).round());
  int get mealPrice => price(8);
  int get waterPrice => price(2);
  int get hotelPrice => price(60);
  int get hostelPrice => price(25);

  void _say(String s) {
    log.insert(0, 'Day $day: $s');
    if (log.length > 40) log.removeLast();
  }

  String? buyMeal() {
    if (phase != Phase.morning) return null;
    if (money < mealPrice) return "You don't have enough money for a meal.";
    if (food >= 100) return "You're too full to eat any more!";
    money -= mealPrice;
    food = math.min(100, food + 40);
    _say('You ate at a café in ${here.name} (£$mealPrice). Yum! 🍔');
    return null;
  }

  String? buyWater() {
    if (phase != Phase.morning) return null;
    if (money < waterPrice) return "You don't have enough money for water.";
    if (water >= 100) return "Your water bottle is already full!";
    money -= waterPrice;
    water = math.min(100, water + 40);
    _say('You bought a big bottle of water (£$waterPrice). 💧');
    return null;
  }

  String sayHello(math.Random rnd) {
    if (saidHelloToday) return "You've already chatted to people today.";
    saidHelloToday = true;
    if (rnd.nextDouble() < 0.6) {
      final name = _friendNames[rnd.nextInt(_friendNames.length)];
      final f = Friend(name, here.name, here.flag);
      friends.add(f);
      final s =
          'You made a new friend: $name from ${here.name} ${here.flag}! 🤝';
      _say(s);
      return s;
    }
    const busy = [
      'You said hello, but everyone was in a hurry.',
      'You waved at someone, but they were on the phone.',
      'You chatted about the weather. Nice, but no new friends today.',
    ];
    final s = busy[rnd.nextInt(busy.length)];
    _say(s);
    return s;
  }

  /// Travel for the day. Afterwards you have to choose where to sleep.
  void travel(math.Random rnd) {
    if (phase != Phase.morning) return;
    if (atPort) {
      final cost = here.boatToNext;
      if (money < cost) {
        _say(
            "The boat to ${next!.name} costs £$cost and you only have £$money. "
            'Rest and wait for payday or help from friends.');
        return;
      }
      money -= cost;
      km = cityKm[cityIndex + 1];
      food = math.max(0, food - 20);
      water = math.max(0, water - 20);
      _say('You took the boat to ${here.name} ${here.flag} (£$cost). ⛴️');
      phase = Phase.evening;
      return;
    }
    final v = vehicle;
    var dist = v.kmPerDay * (0.4 + 0.6 * energy / 100);
    var extra = '';
    final roll = rnd.nextDouble();
    if (roll < 0.08) {
      energy = math.max(0, energy - 10);
      extra = ' It poured with rain ☔ and you got soaked.';
    } else if (roll < 0.14) {
      money += 5;
      extra = ' You found £5 on the path! 🪙';
    } else if (roll < 0.20) {
      food = math.min(100, food + 15);
      extra = ' A kind farmer gave you an apple. 🍎';
    } else if (roll < 0.25 && v.name != 'Walking') {
      dist *= 0.6;
      extra = ' Oh no, a puncture! 🔧 It slowed you down.';
    } else if (roll < 0.30) {
      extra = ' You saw a beautiful sunset. 🌅';
    }
    // Stop at the port if the next leg is over the sea.
    var target = km + dist;
    for (var i = cityIndex; i < route.length - 1; i++) {
      if (route[i].boatToNext > 0 &&
          cityKm[i] > km + 0.001 &&
          cityKm[i] < target) {
        target = cityKm[i];
        break;
      }
    }
    target = math.min(target, totalKm);
    final moved = target - km;
    final before = cityIndex;
    km = target;
    food = math.max(0, food - 30);
    water = math.max(0, water - 35);
    energy = math.max(0, energy - v.tiring);
    var msg = '${v.emoji} You went ${moved.round()} km.';
    if (cityIndex != before) msg += ' You reached ${here.name} ${here.flag}!';
    if (atPort) {
      msg += " There's a boat to ${next!.name} tomorrow (£${here.boatToNext}).";
    }
    _say(msg + extra);
    if (km >= totalKm) {
      phase = Phase.won;
      _say('You made it all the way to Sydney! 🇦🇺🎉');
      return;
    }
    phase = Phase.evening;
  }

  /// Stay put for a day to get your energy back.
  void rest() {
    if (phase != Phase.morning) return;
    food = math.max(0, food - 15);
    water = math.max(0, water - 20);
    energy = math.min(100, energy + 20);
    _say('You had a lazy day in ${here.name}. 😌');
    phase = Phase.evening;
  }

  int sleepPrice(Sleep s) => switch (s) {
        Sleep.hotel => hotelPrice,
        Sleep.hostel => hostelPrice,
        Sleep.camp || Sleep.campervan => 0,
      };

  bool canSleep(Sleep s) =>
      money >= sleepPrice(s) &&
      (s != Sleep.campervan || vehicle.name == 'Campervan');

  /// Go to sleep, then wake up on the next day.
  void sleep(Sleep s, math.Random rnd) {
    if (phase != Phase.evening || !canSleep(s)) return;
    money -= sleepPrice(s);
    switch (s) {
      case Sleep.hotel:
        energy = math.min(100, energy + 60);
        health = math.min(100, health + 10);
        _say('You slept in a comfy hotel (£$hotelPrice). 🏨');
      case Sleep.hostel:
        energy = math.min(100, energy + 45);
        _say('You slept in a hostel bunk bed (£$hostelPrice). 🛏️');
      case Sleep.camp:
        energy = math.min(100, energy + 25);
        _say('You camped under the stars. Free, but a bit chilly! ⛺');
      case Sleep.campervan:
        energy = math.min(100, energy + 55);
        _say('You slept in your cosy campervan. 🚐');
    }
    _nextDay(rnd);
  }

  void _nextDay(math.Random rnd) {
    // Being hungry, thirsty or worn out makes you poorly.
    if (food == 0) health -= 20;
    if (water == 0) health -= 25;
    if (energy == 0) health -= 10;
    if (food > 30 && water > 30) health = math.min(100, health + 5);
    health = health.clamp(0, 100);

    final oldVehicle = vehicle;
    final oldMonth = month;
    day++;
    saidHelloToday = false;
    phase = Phase.morning;
    final news = <String>[];

    if (month != oldMonth) {
      money += monthlyMoney;
      news.add('💷 Payday! You got £$monthlyMoney for month $month.');
      _say('Payday! +£$monthlyMoney 💷');
    }
    if (vehicle != oldVehicle) {
      news.add('🎉 New vehicle: ${vehicle.name} ${vehicle.emoji}! '
          'You can go ${vehicle.kmPerDay} km a day now.');
      _say('You got a ${vehicle.name}! ${vehicle.emoji}');
    }
    for (final f in friends) {
      if (rnd.nextDouble() < 0.06) {
        if (rnd.nextBool()) {
          final gift = 10 + rnd.nextInt(21);
          money += gift;
          _say('Your friend ${f.name} ${f.flag} sent you £$gift! 💌');
        } else {
          food = math.min(100, food + 30);
          _say('Your friend ${f.name} ${f.flag} sent you a packed lunch! 🥪');
        }
        break;
      }
    }
    if (health <= 0) {
      phase = Phase.lost;
      _say('You got too poorly and had to fly home. 🚑');
    } else if (health <= 30) {
      _say('⚠️ You feel poorly. Eat, drink and rest!');
    }
    this.news = news.isEmpty ? null : news.join('\n\n');
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'money': money,
        'health': health,
        'food': food,
        'water': water,
        'energy': energy,
        'km': km,
        'friends': [for (final f in friends) f.toJson()],
        'log': log,
        'hello': saidHelloToday,
        'phase': phase.name,
      };

  static WalkGame fromJson(Map<String, dynamic> j) {
    final g = WalkGame()
      ..day = j['day'] as int
      ..money = j['money'] as int
      ..health = j['health'] as int
      ..food = j['food'] as int
      ..water = j['water'] as int
      ..energy = j['energy'] as int
      ..km = (j['km'] as num).toDouble()
      ..saidHelloToday = j['hello'] as bool
      ..phase = Phase.values.byName(j['phase'] as String);
    g.friends.addAll([
      for (final f in j['friends'] as List)
        Friend.fromJson(Map<String, dynamic>.from(f as Map))
    ]);
    g.log
      ..clear()
      ..addAll([for (final s in j['log'] as List) s as String]);
    return g;
  }
}
