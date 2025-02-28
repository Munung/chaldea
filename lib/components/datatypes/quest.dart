part of datatypes;

@JsonSerializable(checked: true)
class Quest {
  String chapter;
  String name;
  String? nameJp;
  String? nameEn;

  /// one place one quest: use place as key
  /// one place two quests: place（name）
  /// daily quests: name
  String? indexKey;
  int level;
  int bondPoint;
  int experience;
  int qp;
  bool isFree;
  bool hasChoice;
  List<Battle> battles;
  Map<String, int> rewards;
  String? enhancement;
  String? conditions;

  Quest({
    required this.chapter,
    required this.name,
    required this.nameEn,
    required this.nameJp,
    required this.indexKey,
    required this.level,
    required this.bondPoint,
    required this.experience,
    required this.qp,
    required this.isFree,
    required this.hasChoice,
    required this.battles,
    required this.rewards,
    required this.enhancement,
    required this.conditions,
  });

  static LocalizedGroup get questNameGroup => const LocalizedGroup([
        LocalizedText(chs: '周日', jpn: '日曜', eng: 'SUN:'),
        LocalizedText(chs: '周一', jpn: '月曜', eng: 'MON:'),
        LocalizedText(chs: '周二', jpn: '火曜', eng: 'TUE:'),
        LocalizedText(chs: '周三', jpn: '水曜', eng: 'WED:'),
        LocalizedText(chs: '周四', jpn: '木曜', eng: 'THU:'),
        LocalizedText(chs: '周五', jpn: '金曜', eng: 'FRI:'),
        LocalizedText(chs: '周六', jpn: '土曜', eng: 'SAT:'),
        LocalizedText(chs: '剑之修炼场', jpn: '剣の修練場', eng: 'Saber Training Ground'),
        LocalizedText(
            chs: '弓之修炼场', jpn: '弓の修練場', eng: 'Archer Training Ground'),
        LocalizedText(
            chs: '枪之修炼场', jpn: '槍の修練場', eng: 'Lancer Training Ground'),
        LocalizedText(
            chs: '狂之修炼场', jpn: '狂の修練場', eng: 'Berserker Training Ground'),
        LocalizedText(chs: '骑之修炼场', jpn: '騎の修練場', eng: 'Rider Training Ground'),
        LocalizedText(
            chs: '术之修炼场', jpn: '術の修練場', eng: 'Caster Training Ground'),
        LocalizedText(
            chs: '杀之修炼场', jpn: '殺の修練場', eng: 'Assassin Training Ground'),
        LocalizedText(chs: '初级', jpn: '初級', eng: 'Novice'),
        LocalizedText(chs: '中级', jpn: '中級', eng: 'Intermediate'),
        LocalizedText(chs: '上级', jpn: '上級', eng: 'Advanced'),
        LocalizedText(chs: '超级', jpn: '超級', eng: 'Expert'),
        LocalizedText(chs: '极级', jpn: '極級', eng: 'Extreme'),
        LocalizedText(
            chs: '打开宝物库之门', jpn: '宝物庫の扉を開け', eng: 'Enter the Treasure Vault'),
      ]);

  static LocalizedGroup get _emberClsNameGroup => const LocalizedGroup([
        LocalizedText(chs: '剑·骑', jpn: '剣·騎', eng: 'Saber/Rider'),
        LocalizedText(chs: '弓·术', jpn: '弓·術', eng: 'Archer/Caster'),
        LocalizedText(chs: '枪·杀', jpn: '槍·殺', eng: 'Lancer/Assassin'),
        LocalizedText(chs: '随机', jpn: 'ランダム', eng: 'Random'),
      ]);

  static String getDailyQuestName(String name) {
    return name.split(' ').map((e) => questNameGroup.of(e)).join(' ');
  }

  /// [key] is [indexKey] which is used as map key
  String get localizedKey {
    if (indexKey == place) {
      return localizedPlace;
    } else if (name.contains('搜集种火') ||
        name.contains('修炼场') ||
        name.contains('宝物库')) {
      return localizedName;
    } else {
      return '$localizedPlace ($localizedName)';
    }
  }

  String get localizedName {
    if (nameEn == null && nameJp == null) {
      if (name.startsWith('幕间') || name.startsWith('强化')) {
        List<String> fragments = name.split(' ');
        if (fragments.length >= 2) {
          return [
            Localized.chapter.of(fragments[0]),
            db.gameData.servants.values
                    .firstWhereOrNull((svt) => svt.mcLink == fragments[1])
                    ?.info
                    .localizedName ??
                name,
            ...fragments.sublist(2),
          ].join(' ');
        }
      }
      if (name.contains('搜集种火')) {
        return name.replaceFirstMapped(RegExp(r'^搜集种火<(.+)篇> (.+)$'), (match) {
          final c1 = _emberClsNameGroup.of(match.group(1)!),
              c2 = questNameGroup.of(match.group(2)!);
          return LocalizedText.of(
              chs: name,
              jpn: '種火集め<$c1編> $c2',
              eng: 'Ember Gathering <$c1> - $c2');
        });
      }
      if (name.contains('修炼场') || name.contains('宝物库')) {
        return name.replaceAllMapped(
            RegExp(r'\S+'), (match) => questNameGroup.of(match.group(0)!));
      }
    }
    return localizeNoun(name, nameJp, nameEn);
  }

  String get localizedPlace => localizeNoun(place, placeJp, placeEn);

  String? get place => battles.getOrNull(0)?.place;

  String? get placeJp => battles.getOrNull(0)?.placeJp;

  String? get placeEn => battles.getOrNull(0)?.placeEn;

  static String shortChapterOf(String chapter) {
    if (Language.isEnOrKr) {
      return Localized.chapter.of(chapter).split(':').first;
    }
    if (chapter.contains('每日任务')) {
      return '每日任务';
    } else if (chapter.contains('特异点')) {
      // 第一部
      return chapter.split(' ').last;
    } else if (chapter.toLowerCase().contains('lostbelt')) {
      return chapter.split(' ')[2];
    } else {
      return chapter.split(' ')[0];
    }
  }

  factory Quest.fromJson(Map<String, dynamic> data) => _$QuestFromJson(data);

  Map<String, dynamic> toJson() => _$QuestToJson(this);
}

@JsonSerializable(checked: true)
class Battle {
  int ap;
  String? place;
  String? placeJp;
  String? placeEn;
  List<List<Enemy?>> enemies; // wave_num*enemy_num
  Map<String, int> drops;

  Battle({
    required this.ap,
    required this.place,
    required this.placeJp,
    required this.placeEn,
    required this.enemies,
    required this.drops,
  });

  factory Battle.fromJson(Map<String, dynamic> data) => _$BattleFromJson(data);

  Map<String, dynamic> toJson() => _$BattleToJson(this);
}

@JsonSerializable(checked: true)
class Enemy {
  List<String?> name;
  List<String?> shownName;
  List<String?> className;
  List<int> rank;
  List<int> hp;

  Enemy({
    required this.name,
    required this.shownName,
    required this.className,
    required this.rank,
    required this.hp,
  });

  factory Enemy.fromJson(Map<String, dynamic> data) => _$EnemyFromJson(data);

  Map<String, dynamic> toJson() => _$EnemyToJson(this);
}
