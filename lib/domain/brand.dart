class BrandPreset {
  const BrandPreset(this.id, this.title, this.tagline, this.disclaimer);
  final String id;
  final String title;
  final String tagline;
  final String disclaimer;
}

const brandPresets = {
  'pairs': BrandPreset('pairs', 'Расписание пар', 'Ваш учебный день', 'Неофициальное приложение с открытым исходным кодом'),
  'donntu': BrandPreset('donntu', 'Расписание ДонНТУ', 'Расписание и данные ACE', 'Неофициальное приложение с открытым исходным кодом'),
};

BrandPreset brandFor(String? id) => brandPresets[id] ?? brandPresets['pairs']!;

class Features {
  const Features({this.knowledge = false, this.community = false, this.friends = false, this.campus = false});
  final bool knowledge;
  final bool community;
  final bool friends;
  final bool campus;

  factory Features.fromJson(Map<String, dynamic> j) => Features(
        knowledge: j['knowledge'] as bool? ?? false,
        community: j['community'] as bool? ?? false,
        friends: j['friends'] as bool? ?? false,
        campus: j['campus'] as bool? ?? false,
      );

  Features copyWith({bool? campus, bool? knowledge, bool? community, bool? friends}) => Features(
        knowledge: knowledge ?? this.knowledge,
        community: community ?? this.community,
        friends: friends ?? this.friends,
        campus: campus ?? this.campus,
      );

  bool flag(String name) => switch (name) {
        'knowledge' => knowledge,
        'community' => community,
        'friends' => friends,
        'campus' => campus,
        _ => true,
      };
}

const serviceFeature = {
  'knowledge': 'knowledge',
  'communities': 'community',
  'polls': 'community',
  'campus': 'campus',
};

bool serviceVisible(String route, Features features) => !serviceFeature.containsKey(route) || features.flag(serviceFeature[route]!);
