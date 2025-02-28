import 'package:auto_size_text/auto_size_text.dart';
import 'package:chaldea/components/components.dart';
import 'package:chaldea/modules/item/item_detail_page.dart';
import 'package:flutter_picker/flutter_picker.dart';

import 'filter_dialog.dart';

class DropCalcInputTab extends StatefulWidget {
  final Map<String, int>? objectiveCounts;
  final ValueChanged<GLPKSolution>? onSolved;

  DropCalcInputTab({Key? key, this.objectiveCounts, this.onSolved})
      : super(key: key);

  @override
  _DropCalcInputTabState createState() => _DropCalcInputTabState();
}

class _DropCalcInputTabState extends State<DropCalcInputTab> {
  late ScrollController _scrollController;

  GLPKParams get params => db.curUser.glpkParams;

  // category - itemKey
  Map<String, List<String>> pickerData = {};
  List<PickerItem<String>> pickerAdapter = [];
  final GLPKSolver solver = GLPKSolver();
  bool running = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.objectiveCounts != null) {
      params.rows.clear();
      widget.objectiveCounts!.forEach((key, count) {
        if (!params.rows.contains(key)) {
          params.rows.add(key);
          params.planItemCounts[key] = count;
        }
      });
    } else {
      if (params.rows.isEmpty) {
        addAnItemNotInList();
        addAnItemNotInList();
      }
    }
    params.sortByItem();
    // update userdata at last
    solver.ensureEngine();
  }

  final String specialCategory = 'Special';

  void setPickerData() {
    // picker
    pickerData.clear();
    pickerData[specialCategory] = List.of(Items.specialPlanItems);

    db.gameData.items.keys.forEach((name) {
      final category = getItemCategory(name);
      if (category != null) {
        pickerData.putIfAbsent(category, () => []).add(name);
      }
    });

    Widget makeText({required String text, Widget? icon}) {
      Widget child = AutoSizeText(
        text,
        maxLines: 2,
        maxFontSize: 15,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).textTheme.bodyText1?.color),
      );
      if (icon != null) {
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [icon, Expanded(child: child)],
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(child: child),
      );
    }

    pickerData.forEach((category, items) {
      if (category == specialCategory) {
        pickerAdapter.add(PickerItem(
          text: makeText(
              text: LocalizedText.of(chs: '特殊', jpn: '特別', eng: 'Special')),
          value: specialCategory,
          children: items
              .map((e) => PickerItem(
                    text: makeText(text: Item.lNameOf(e)),
                    value: e,
                  ))
              .toList(),
        ));
        return;
      }
      pickerAdapter.add(PickerItem(
        text: makeText(text: category.replaceFirst(RegExp(r' Items$'), '')),
        value: category,
        children: items
            .map((e) => PickerItem(
                  text: makeText(
                    text: Item.lNameOf(e),
                    icon: Item.iconBuilder(
                        context: context, itemKey: e, height: 28),
                  ),
                  value: e,
                ))
            .toList(),
      ));
    });
  }

  @override
  void dispose() {
    solver.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pickerData.isEmpty) setPickerData();
    return Column(
      children: <Widget>[
        Material(
          child: ListTile(
            title: Text(S.of(context).item),
            contentPadding: const EdgeInsets.only(left: 18, right: 8),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 65,
                  child: Center(
                    child: Text(planOrEff
                        ? S.of(context).counts
                        : S.of(context).calc_weight),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    SimpleCancelOkDialog(
                      title: Text(S.current.clear),
                      onTapOk: () {
                        setState(() {
                          params.rows.clear();
                        });
                      },
                    ).showDialog(context);
                  },
                )
              ],
            ),
          ),
          elevation: 1,
        ),
        if (params.rows.isEmpty)
          ListTile(
              title: Center(child: Text(S.of(context).drop_calc_empty_hint))),
        Expanded(child: _buildInputRows()),
        kDefaultDivider,
        _buildButtonBar(),
      ],
    );
  }

  Widget _buildInputRows() {
    return ListView.separated(
      controller: _scrollController,
      itemBuilder: (context, index) {
        final item = params.rows[index];
        Widget leading = GestureDetector(
          onTap: () {
            SplitRoute.push(context, ItemDetailPage(itemKey: item));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: db.getIconImage(
              Items.specialPlanItems.contains(item)
                  ? (item == Items.bondPoint ? Items.chaldeaLantern : null)
                  : item,
              height: 48,
            ),
          ),
        );
        Widget title = TextButton(
          style: TextButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(48, 28),
            padding: PlatformU.isMobile
                ? const EdgeInsets.symmetric(horizontal: 8)
                : null,
          ),
          child: Text(Item.lNameOf(item)),
          onPressed: () {
            getPicker(
              item: item,
              onSelected: (v) {
                setState(() {
                  params.rows[index] = v;
                });
              },
            ).showDialog(context);
          },
        );
        Widget subtitle = Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            planOrEff
                ? S.current.words_separate(
                    S.current.calc_weight, params.getPlanItemWeight(item))
                : S.current.words_separate(
                    S.current.counts, params.getPlanItemCount(item)),
          ),
        );
        return CustomTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          titlePadding: const EdgeInsets.only(right: 6),
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 65,
                child: TextField(
                  key: Key('calc_input_$item'),
                  controller: TextEditingController(
                      text: planOrEff
                          ? params.getPlanItemCount(item).toString()
                          : params.getPlanItemWeight(item).toString()),
                  keyboardType: const TextInputType.numberWithOptions(
                      signed: true, decimal: true),
                  textAlign: TextAlign.center,
                  // textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(isDense: true),
                  // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (s) {
                    if (planOrEff) {
                      int? v = int.tryParse(s);
                      if (v != null) params.planItemCounts[item] = v;
                    } else {
                      double? v = double.tryParse(s);
                      if (v != null) params.planItemWeights[item] = v;
                    }
                  },
                ),
              ),
              IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  focusNode: FocusNode(skipTraversal: true),
                  onPressed: () {
                    setState(() {
                      params.rows.remove(item);
                    });
                  })
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => kDefaultDivider,
      itemCount: params.rows.length,
    );
  }

  Picker getPicker({String? item, required ValueChanged<String> onSelected}) {
    String? category;
    if (item != null) category = getItemCategory(item);
    return Picker(
      adapter: PickerDataAdapter<String>(data: pickerAdapter),
      selecteds: [
        // default Bronze
        category == null ? 2 : pickerData.keys.toList().indexOf(category),
        category == null || item == null
            ? 0
            : pickerData[category]!.indexOf(item)
      ],
      height: min(250, MediaQuery.of(context).size.height - 200),
      itemExtent: 48,
      changeToFirst: true,
      hideHeader: true,
      textScaleFactor: 0.7,
      backgroundColor: null,
      cancelText: S.current.cancel,
      confirmText: S.current.confirm,
      columnFlex: [3, 5],
      onConfirm: (Picker picker, List<int> value) {
        print('picker: ${picker.getSelectedValues()}');
        setState(() {
          String selected = picker.getSelectedValues().last;
          if (params.rows.contains(selected)) {
            EasyLoading.showToast(
                S.current.item_already_exist_hint(Item.lNameOf(selected)));
          } else {
            onSelected(selected);
            // params.rows[index] = selected;
          }
        });
      },
    );
  }

  Widget _buildButtonBar() {
    return ButtonBar(
      alignment: MainAxisAlignment.center,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: <Widget>[
                DropdownButton<bool>(
                  value: planOrEff,
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                        value: true, child: Text(S.of(context).plan)),
                    DropdownMenuItem(
                        value: false, child: Text(S.of(context).efficiency))
                  ],
                  onChanged: (v) => setState(() => planOrEff = v ?? planOrEff),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              color: params.minCost > 0 ||
                      params.maxColNum > 0 ||
                      params.blacklist.isNotEmpty ||
                      !params.use6th
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              tooltip: S.of(context).settings_tab_name,
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (context) => FreeCalcFilterDialog(params: params));
                setState(() {});
              },
            ),
            //TODO: add extra event quests button
            IconButton(
              icon: const Icon(Icons.sort),
              tooltip: S.of(context).filter_sort,
              color: Theme.of(context).colorScheme.primary,
              onPressed: () {
                setState(() {
                  params.sortByItem();
                });
              },
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Add',
                  onPressed: () {
                    getPicker(
                      item: params.dropRatesData.rowNames
                          .firstWhereOrNull((e) => !params.rows.contains(e)),
                      onSelected: (v) {
                        setState(() {
                          params.rows.add(v);
                        });
                      },
                    ).showDialog(context);
                  },
                ),
                ElevatedButton(
                  onPressed: running ? null : solve,
                  child: Text(S.of(context).drop_calc_solve),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  void addAnItemNotInList() {
    final item = params.dropRatesData.rowNames
        .firstWhereOrNull((e) => !params.rows.contains(e));
    if (item != null) params.rows.add(item);
  }

  // here category is localized
  String? getItemCategory(String itemKey) {
    if (Items.specialPlanItems.contains(itemKey)) return specialCategory;
    final item = db.gameData.items[itemKey];
    if (item == null) return null;
    if (item.category == ItemCategory.item) {
      if (item.rarity <= 3) {
        return <String?>[
          null,
          S.current.item_category_bronze,
          S.current.item_category_silver,
          S.current.item_category_gold
        ][item.rarity];
      }
    } else if (item.category == ItemCategory.gem) {
      return S.current.item_category_gems;
    } else if (item.category == ItemCategory.ascension) {
      return S.current.item_category_ascension;
    }
    return null;
  }

  bool planOrEff = true;

  void solve() async {
    FocusScope.of(context).unfocus();
    if (params.counts.reduce(max) > 0) {
      setState(() {
        running = true;
      });
      final solution = await solver.calculate(params: params);
      running = false;
      solution.destination = planOrEff ? 1 : 2;
      solution.params = params;
      if (widget.onSolved != null) {
        widget.onSolved!(solution);
      }
      MobStat.logEvent('free_calc');
    } else {
      EasyLoading.showToast(S.of(context).input_invalid_hint);
    }
  }
}
