import 'package:chaldea/components/components.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticServantTab extends StatefulWidget {
  StatisticServantTab({Key? key}) : super(key: key);

  @override
  _StatisticServantTabState createState() => _StatisticServantTabState();
}

class _StatisticServantTabState extends State<StatisticServantTab> {
  late ScrollController _scrollController;

  /// disable scroll of ListView when pie chart is touched
  bool scrollable = true;

  List<int> rarityTotal = List.filled(6, 0);
  List<int> rarityOwn = List.filled(6, 0);
  List<int> rarity999 = List.filled(6, 0);
  List<bool> raritySelected = List.filled(6, true);

  void _calcRarityCounts() {
    if (rarityTotal.every((e) => e == 0)) {
      db.gameData.servants.forEach((no, svt) {
        if (!svt.isAvailable) return;
        rarityTotal[svt.info.rarity] += 1;
        final stat = db.curUser.svtStatusOf(no);
        if (stat.favorite) {
          rarityOwn[svt.info.rarity] += 1;
        }
        if (stat.curVal.skills.every((e) => e >= 9)) {
          rarity999[svt.info.rarity] += 1;
        }
      });
    }
  }

  Map<String, int> svtClassCount = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    super.dispose();
    _scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _calcRarityCounts();
    List<Widget> children = [];
    children.add(pieChart());
    children.add(ListTile(
      title: Text(S.current.rarity),
      trailing: const Text('(skillMax)  own/total'),
      // dense: true,
    ));
    children.addAll(_oneRarity(
      selected: raritySelected.every((e) => e),
      title: 'ALL',
      skillMax: sum(rarity999),
      own: sum(rarityOwn),
      total: sum(rarityTotal),
      onChanged: (v) {
        setState(() {
          raritySelected.fillRange(0, raritySelected.length, v);
        });
      },
    ));
    for (int i = rarityTotal.length - 1; i >= 0; i--) {
      children.addAll(_oneRarity(
        selected: raritySelected[i],
        title: '$i☆ ' + S.current.servant,
        skillMax: rarity999[i],
        own: rarityOwn[i],
        total: rarityTotal[i],
        onChanged: (v) {
          setState(() {
            raritySelected[i] = v;
          });
        },
      ));
    }
    children.add(const Center(
      child: Text(
        'Red: skill >=999',
        style: TextStyle(color: Colors.grey),
      ),
    ));
    return ListView(
      controller: _scrollController,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      children: divideTiles(children),
      padding: const EdgeInsets.symmetric(vertical: 6),
    );
  }

  List<Widget> _oneRarity({
    required bool selected,
    required String title,
    required int skillMax,
    required int own,
    required int total,
    required ValueChanged<bool> onChanged,
  }) {
    return [
      CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        value: selected,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        title: Row(
          children: [
            Expanded(child: Text(title)),
            Text(
              '($skillMax) ' + '$own/$total'.padLeft(7),
              style: kMonoStyle,
            )
          ],
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Container(height: 8, color: Colors.red[400]),
            flex: skillMax,
          ),
          Expanded(
            child: Container(
              height: 8,
              color: Colors.blue,
            ),
            flex: own - skillMax,
          ),
          Expanded(
            child: Container(height: 8, color: Colors.grey[300]),
            flex: total - own,
          ),
        ],
      ),
    ];
  }

  final String otherClass = 'Others';

  void _calcServantClass() {
    svtClassCount = Map.fromIterable(
        SvtFilterData.classesData.sublist(0, 7)..add(otherClass),
        value: (_) => 0);
    db.gameData.servants.values.forEach((svt) {
      if (db.curUser.svtStatusOf(svt.no).favorite) {
        if (raritySelected.contains(true) && !raritySelected[svt.info.rarity]) {
          return;
        }
        if (svtClassCount.containsKey(svt.stdClassName)) {
          svtClassCount[svt.stdClassName] =
              (svtClassCount[svt.stdClassName] ?? 0) + 1;
        } else {
          svtClassCount[otherClass] = (svtClassCount[otherClass] ?? 0) + 1;
        }
      }
    });
    svtClassCount.removeWhere((key, value) => value <= 0);
    // print(svtClassCount);
  }

  String? selectedPie;

  List<Color> get palette => const [
        // Color(0xFFCC0000),
        Color(0xFFCC6600),
        Color(0xFFCCCC00),
        Color(0xFF66CC00),
        Color(0xFF00CC00),
        Color(0xFF00CC66),
        Color(0xFF00CCCC),
        Color(0xFF0066CC),
        Color(0xFF0000CC),
        // Color(0xFF6600CC),
        // Color(0xFFCC00CC),
        // Color(0xFFCC0066),
      ].reversed.toList();

  Widget pieChart() {
    _calcServantClass();
    int total = sum(svtClassCount.values);
    final iter = palette.iterator;
    return LayoutBuilder(
      builder: (context, constraints) {
        double mag = min(1, constraints.maxWidth / 350);
        if (total <= 0) return Container(height: 280 * mag);
        iter.moveNext();
        return SizedBox(
          height: 280 * mag,
          child: PieChart(PieChartData(
            sections: List.generate(svtClassCount.length, (index) {
              final entry = svtClassCount.entries.elementAt(index);
              return _pieSection(
                  entry.key, entry.value, total, mag, palette[index]);
            }),
            centerSpaceRadius: 0,
            pieTouchData:
                PieTouchData(touchCallback: (event, pieTouchResponse) {
              if (pieTouchResponse == null) return;
              bool _needsBuild = false;
              if (event is FlTapUpEvent &&
                  pieTouchResponse.touchedSection != null &&
                  pieTouchResponse.touchedSection!.touchedSectionIndex >= 0) {
                scrollable = false;
                _needsBuild = true;
              }
              if (event is FlTapUpEvent || event is FlTapCancelEvent) {
                scrollable = true;
                _needsBuild = true;
              }
              final desiredTouch =
                  event is! FlTapUpEvent && event is! FlTapCancelEvent;
              if (desiredTouch && pieTouchResponse.touchedSection != null) {
                String? _newSelected;
                int index =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
                if (index >= 0 && index < svtClassCount.length) {
                  _newSelected = svtClassCount.keys.elementAt(index);
                } else {
                  _newSelected = null;
                }
                if (selectedPie != _newSelected) {
                  selectedPie = _newSelected;
                  _needsBuild = true;
                }
              }
              if (_needsBuild) {
                setState(() {});
              }
            }),
          )),
        );
      },
    );
  }

  PieChartSectionData _pieSection(
      String clsName, int count, int total, double mag, Color? color) {
    bool selected = selectedPie == clsName;
    double ratio = count / total;
    double posRatio = ratio < 0.05 ? 1.2 : 1;
    return PieChartSectionData(
      value: count.toDouble(),
      title: selected
          ? '$count\n(${(ratio * 100).toStringAsFixed(0) + '%'})'
          : count.toString(),
      titleStyle: TextStyle(
          color: Colors.white, fontSize: 16 * mag, fontWeight: FontWeight.bold),
      radius: (selected ? 120 : 100) * mag,
      badgeWidget: db.getIconImage(
        '金卡${clsName == otherClass ? "All" : clsName}',
        width: 30 * mag,
        height: 30 * mag,
      ),
      badgePositionPercentageOffset: 1 * posRatio,
      titlePositionPercentageOffset: 0.6 * posRatio,
      color: color,
    );
  }
}
