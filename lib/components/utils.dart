import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chaldea/generated/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:kana_kit/kana_kit.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/custom_dialogs.dart';
import 'config.dart' show db;
import 'constants.dart';
import 'extensions.dart';
import 'logger.dart';

/// Math related
///

/// Format number
///
/// If [compact] is true, other parameters are not used.
String formatNumber(num? number,
    {bool compact = false,
    bool percent = false,
    bool omit = true,
    int precision = 3,
    String? groupSeparator = ',',
    num? minVal}) {
  assert(!compact || !percent);
  if (number == null || (minVal != null && number.abs() < minVal.abs())) {
    return number.toString();
  }

  if (compact) {
    return NumberFormat.compact(locale: 'en').format(number);
  }

  final pattern = [
    if (groupSeparator != null) '###' + groupSeparator,
    '###',
    if (precision > 0) '.' + (omit ? '#' : '0') * precision,
    if (percent) '%'
  ].join();
  return NumberFormat(pattern).format(number);
}

class NumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    int? value = int.tryParse(newValue.text);
    if (value == null) {
      return newValue;
    }
    String newText = formatNumber(value);
    return newValue.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length));
  }
}

dynamic deepCopy(dynamic obj) {
  return jsonDecode(jsonEncode(obj));
}

class MathUtils {
  MathUtils._();

  static T _convertNum<T extends num>(num a) {
    if (T == int) {
      return a.toInt() as T;
    } else {
      return a.toDouble() as T;
    }
  }

  static T max<T extends num>(Iterable<T> iterable) {
    return iterable.fold<T>(_convertNum<T>(0), (p, c) => math.max(p, c));
  }

  static T min<T extends num>(Iterable<T> iterable) {
    return iterable.fold<T>(_convertNum<T>(0), (p, c) => math.min(p, c));
  }

  static T sum<T extends num>(Iterable<T?> iterable) {
    return iterable.fold<T>(
        _convertNum(0), (p, c) => (p + (c ?? _convertNum<T>(0))) as T);
  }

  static bool inRange<T extends Comparable>(T? value, T lower, T upper,
      [bool includeEnds = true]) {
    if (value == null) return false;
    if (includeEnds) {
      return value.compareTo(lower) >= 0 && value.compareTo(upper) <= 0;
    } else {
      return value.compareTo(lower) > 0 && value.compareTo(upper) < 0;
    }
  }

  static MapEntry<double, double>? fitSize(
      double? width, double? height, double? aspectRatio) {
    if (aspectRatio == null || (width == null && height == null)) return null;
    if (width != null && height != null) {
      if (width / aspectRatio < height) {
        return MapEntry(width, width / aspectRatio);
      } else {
        return MapEntry(height * aspectRatio, height);
      }
    }
    if (width != null) return MapEntry(width, width / aspectRatio);
    if (height != null) return MapEntry(height * aspectRatio, height);
  }
}

/// Sum a list of number, list item defaults to 0 if null
T sum<T extends num>(Iterable<T?> x) {
  if (0 is T) {
    return x.fold(0 as T, (p, c) => (p + (c ?? 0)) as T);
  } else {
    return x.fold(0.0 as T, (p, c) => (p + (c ?? 0.0)) as T);
  }
}

/// Sum a list of maps, map value must be number.
/// iI [inPlace], the result is saved to the first map.
/// null elements will be skipped.
/// throw error if sum an empty list in place.
Map<K, V> sumDict<K, V extends num>(Iterable<Map<K, V>?> operands,
    {bool inPlace = false}) {
  final _operands = operands.toList();

  Map<K, V> res;
  if (inPlace) {
    assert(_operands[0] != null);
    res = _operands.removeAt(0)!;
  } else {
    res = {};
  }

  for (var m in _operands) {
    m?.forEach((k, v) {
      res[k] = ((res[k] ?? 0) + v) as V;
    });
  }
  return res;
}

/// Multiply the values of map with a number.
Map<K, V> multiplyDict<K, V extends num>(Map<K, V> d, V multiplier,
    {bool inPlace = false}) {
  Map<K, V> res = inPlace ? d : {};
  d.forEach((k, v) {
    res[k] = (v * multiplier) as V;
  });
  return res;
}

/// [reversed] is used only when [compare] is null for default num values sort
Map<K, V> sortDict<K, V>(Map<K, V> d,
    {bool reversed = false,
    int Function(MapEntry<K, V> a, MapEntry<K, V> b)? compare,
    bool inPlace = false}) {
  List<MapEntry<K, V>> entries = d.entries.toList();
  entries.sort((a, b) {
    if (compare != null) return compare(a, b);
    if (a.value is num && b.value is num) {
      return (a.value as num).compareTo(b.value as num) * (reversed ? -1 : 1);
    }
    throw ArgumentError('must provide "compare" when values is not num');
  });
  final sorted = Map.fromEntries(entries);
  if (inPlace) {
    d.clear();
    d.addEntries(entries);
    return d;
  } else {
    return sorted;
  }
}

String b64(String source, [bool decode = true]) {
  if (decode) {
    return utf8.decode(base64Decode(source));
  } else {
    return base64Encode(utf8.encode(source));
  }
}

Future<dynamic> readAndDecodeJsonAsync({String? fp, String? contents}) async {
  assert(fp != null || contents != null);
  if (fp != null && await File(fp).exists()) {
    contents = await File(fp).readAsString();
  }
  if (contents == null) return null;
  return compute(jsonDecode, contents);
}

T fixValidRange<T extends num>(T value, [T? minVal, T? maxVal]) {
  if (minVal != null) {
    value = math.max(value, minVal);
  }
  if (maxVal != null) {
    value = math.min(value, maxVal);
  }
  return value;
}

void fillListValue<T>(List<T> list, int length, T Function(int index) fill) {
  if (length <= list.length) {
    list.length = length;
  } else {
    list.addAll(
        List.generate(length - list.length, (i) => fill(list.length + i)));
  }
  // fill null if T is nullable
  for (int i = 0; i < length; i++) {
    list[i] ??= fill(i);
  }
}

/// Flutter related
///

void showInformDialog(BuildContext context,
    {String? title,
    String? content,
    List<Widget> actions = const [],
    bool showOk = true,
    bool showCancel = false}) {
  assert(title != null || content != null);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: title == null ? null : Text(title),
      content: content == null ? null : Text(content),
      actions: <Widget>[
        if (showOk)
          TextButton(
            child: Text(S.of(context).confirm),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        if (showCancel)
          TextButton(
            child: Text(S.of(context).cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ...actions
      ],
    ),
  );
}

typedef SheetBuilder = Widget Function(BuildContext, StateSetter);

void showSheet(BuildContext context,
    {required SheetBuilder builder, double size = 0.65}) {
  assert(size >= 0.25 && size <= 1);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        return DraggableScrollableSheet(
          initialChildSize: size,
          minChildSize: 0.25,
          maxChildSize: 1,
          expand: false,
          builder: (context, scrollController) =>
              builder(sheetContext, setSheetState),
        );
      },
    ),
  );
}

double defaultDialogWidth(BuildContext context) {
  return math.min(420, MediaQuery.of(context).size.width * 0.8);
}

double defaultDialogHeight(BuildContext context) {
  return math.min(420, MediaQuery.of(context).size.width * 0.8);
}

/// other utils

class TimeCounter {
  String name;
  final Stopwatch stopwatch = Stopwatch();

  TimeCounter(this.name, {bool autostart = true}) {
    if (autostart) stopwatch.start();
  }

  void start() {
    stopwatch.start();
  }

  void elapsed() {
    final d = stopwatch.elapsed.toString();
    logger.d('Stopwatch - $name: $d');
  }
}

Future<void> jumpToExternalLinkAlert(
    {required String url, String? name}) async {
  String shownLink = url;
  String? safeLink = Uri.tryParse(url)?.toString();
  if (safeLink != null) {
    shownLink = Uri.decodeFull(safeLink);
  }

  return showDialog(
    context: kAppKey.currentContext!,
    builder: (context) => SimpleCancelOkDialog(
      title: Text(S.of(context).jump_to(name ?? S.of(context).link)),
      content: Text(shownLink,
          style: const TextStyle(decoration: TextDecoration.underline)),
      onTapOk: () async {
        String link = safeLink ?? url;
        if (await canLaunch(link)) {
          launch(link);
        } else {
          EasyLoading.showToast('Could not launch url:\n$link');
        }
      },
    ),
  );
}

bool checkEventOutdated(
    {DateTime? timeJp, DateTime? timeCn, Duration? duration}) {
  duration ??= const Duration(days: 27);
  if (db.curUser.msProgress == -1 || db.curUser.msProgress == -2) {
    return DateTime.now().checkOutdated(timeCn, duration);
  } else {
    int ms = db.curUser.msProgress == -3
        ? db.gameData.events.progressTW.millisecondsSinceEpoch
        : db.curUser.msProgress == -4
            ? db.gameData.events.progressNA.millisecondsSinceEpoch
            : db.curUser.msProgress;
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .checkOutdated(timeJp, duration);
  }
}

String _fullChars =
    '０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ－、\u3000／';
String _halfChars =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-, /';

Map<String, String> _fullHalfMap =
    Map.fromIterables(_fullChars.split(''), _halfChars.split(''));

String fullToHalf(String s) {
  String s2 = s.replaceAllMapped(RegExp(r'[０-９Ａ-Ｚ－／　]'),
      (match) => _fullHalfMap[match.group(0)!] ?? match.group(0)!);
  return s2;
}

Future<void> catchErrorSync(
  Function callback, {
  VoidCallback? onSuccess,
  void Function(dynamic, StackTrace?)? onError,
}) async {
  try {
    callback();
    if (onSuccess != null) onSuccess();
  } catch (e, s) {
    if (onError != null) onError(e, s);
  }
}

Future<void> catchErrorAsync(
  Function callback, {
  VoidCallback? onSuccess,
  void Function(dynamic, StackTrace)? onError,
  VoidCallback? whenComplete,
}) async {
  try {
    await callback();
    if (onSuccess != null) onSuccess();
  } catch (e, s) {
    if (onError != null) onError(e, s);
  } finally {
    if (whenComplete != null) whenComplete();
  }
}

class Utils {
  Utils._();

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static T? findNextOrPrevious<T>({
    required List<T> list,
    required T cur,
    bool reversed = false,
    bool defaultFirst = false,
  }) {
    int curIndex = list.indexOf(cur);
    if (curIndex >= 0) {
      int nextIndex = curIndex + (reversed ? -1 : 1);
      if (nextIndex >= 0 && nextIndex < list.length) {
        return list[nextIndex];
      }
    } else if (defaultFirst && list.isNotEmpty) {
      return list.first;
    }
  }

  static void scheduleFrameCallback(VoidCallback callback) {
    SchedulerBinding.instance!.scheduleFrameCallback((timeStamp) {
      callback();
    });
  }

  static KanaKit kanaKit = const KanaKit();

  /// To lowercase alphabet:
  ///   * Chinese->Pinyin
  ///   * Japanese->Romaji
  static String toAlphabet(String text, {Language? lang}) {
    lang ??= Language.current;
    if (lang == Language.chs) {
      return PinyinHelper.getPinyinE(text).toLowerCase();
    } else if (lang == Language.jpn) {
      return kanaKit.toRomaji(text).toLowerCase();
    } else {
      return text.toLowerCase();
    }
  }

  static List<String> getSearchAlphabets(String? textCn,
      [String? textJp, String? textEn]) {
    List<String> list = [];
    if (textEn != null) list.add(textEn);
    if (textCn != null) {
      list.addAll([
        textCn,
        PinyinHelper.getPinyinE(textCn, separator: ''),
        PinyinHelper.getShortPinyin(textCn)
      ]);
    }
    // kanji to Romaji?
    if (textJp != null && textJp.length < 100) {
      try {
        list.addAll([textJp, kanaKit.toRomaji(textJp)]);
      } catch (e, s) {
        logger.e(textJp, e, s);
        rethrow;
      }
    }
    return list;
  }

  static List<String> getSearchAlphabetsForList(List<String>? textsCn,
      [List<String>? textsJp, List<String>? textsEn]) {
    List<String> list = [];
    if (textsEn != null) list.addAll(textsEn);
    if (textsCn != null) {
      for (var text in textsCn) {
        list.addAll([
          text,
          PinyinHelper.getPinyinE(text, separator: ''),
          PinyinHelper.getShortPinyin(text)
        ]);
      }
    }
    if (textsJp != null) {
      for (var text in textsJp) {
        list.addAll([text, kanaKit.toRomaji(text)]);
      }
    }
    return list;
  }

  static void debugChangeDarkMode([ThemeMode? mode]) {
    if (db.appSetting.themeMode != null && mode == db.appSetting.themeMode) {
      return;
    }

    final t = DateTime.now().millisecondsSinceEpoch;
    final _last = db.runtimeData.tempDict['debugChangeDarkMode'] ?? 0;
    if (t - _last < 2000) return;
    db.runtimeData.tempDict['debugChangeDarkMode'] = t;

    if (mode != null) {
      db.appSetting.themeMode = mode;
    } else {
      // don't rebuild
      switch (db.appSetting.themeMode) {
        case ThemeMode.light:
          db.appSetting.themeMode = ThemeMode.dark;
          break;
        case ThemeMode.dark:
          db.appSetting.themeMode = ThemeMode.light;
          break;
        default:
          db.appSetting.themeMode =
              SchedulerBinding.instance!.window.platformBrightness ==
                      Brightness.light
                  ? ThemeMode.dark
                  : ThemeMode.light;
          break;
      }
    }
    debugPrint('change themeMode: ${db.appSetting.themeMode}');
    db.notifyAppUpdate();
  }
}

class DelayedTimer {
  Duration duration;

  Timer? _timer;

  Timer? get timer => _timer;

  DelayedTimer(this.duration);

  /// If want to call [setState], remember to check [mounted]
  Timer delayed(void Function() callback) {
    _timer?.cancel();
    return _timer = Timer(duration, callback);
  }
}

class EasyLoadingUtil {
  EasyLoadingUtil._();

  /// default 2s of EasyLoading
  static Future<void> dismiss(
      [Duration? duration = const Duration(milliseconds: 2200)]) {
    if (duration != null) {
      return Future.delayed(duration, () => EasyLoading.dismiss());
    } else {
      EasyLoading.dismiss();
      return Future.value();
    }
  }
}

class UndraggableScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        // PointerDeviceKind.touch,
        // PointerDeviceKind.mouse,
      };
}
