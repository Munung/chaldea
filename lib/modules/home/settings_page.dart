import 'package:chaldea/components/components.dart';
import 'package:chaldea/modules/home/subpage/dataset_manage_page.dart';
import 'package:flutter/foundation.dart';

import 'subpage/about_page.dart';
import 'subpage/account_page.dart';
import 'subpage/lang_page.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String language;
  String user;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    language = S.of(context).language;
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settings_tab_name)),
      backgroundColor: MyColors.setting_bg,
      body: ListView(
        children: <Widget>[
          TileGroup(
            header: S.of(context).settings_data,
            children: <Widget>[
              ListTile(
                title: Text(S.of(context).settings_tutorial),
              ),
//              ListTile(
//                title: Text(S.of(context).server),
//                trailing: DropdownButtonHideUnderline(
//                  child: DropdownButton<String>(
//                    value: db.userData.users[db.userData.curUsername].server ??
//                        GameServer.jp,
//                    items: <DropdownMenuItem<String>>[
//                      DropdownMenuItem(
//                        value: GameServer.cn,
//                        child: Text(S.of(context).server_cn),
//                      ),
//                      DropdownMenuItem(
//                        value: GameServer.jp,
//                        child: Text(S.of(context).server_jp),
//                      )
//                    ],
//                    onChanged: (v) {
//                      db.userData.users[db.userData.curUsername].server = v;
//                      db.onAppUpdate();
//                    },
//                  ),
//                ),
//              ),
              ListTile(
                title: Text(S.of(context).cur_account),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      db.userData.users[db.userData.curUsername].name,
                      style: TextStyle(color: Colors.black87),
                    ),
                    Icon(Icons.arrow_forward_ios)
                  ],
                ),
                onTap: () {
                  SplitRoute.popAndPush(context,
                      builder: (context) => AccountPage());
                },
              ),
              ListTile(
                title: Text('数据管理'),
                trailing: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(db.gameData.version),
                    Icon(Icons.arrow_forward_ios)
                  ],
                ),
                onTap: () {
                  SplitRoute.popAndPush(context,
                      builder: (context) => DatasetManagePage());
                },
              ),
            ],
          ),
          TileGroup(
            header: S.of(context).settings_general,
            children: <Widget>[
              ListTile(
                title: Text(S.of(context).settings_language),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      S.of(context).language,
                      style: TextStyle(color: Colors.black87),
                    ),
                    Icon(Icons.arrow_forward_ios)
                  ],
                ),
                onTap: () {
                  SplitRoute.popAndPush(context,
                      builder: (context) => LanguagePage());
                },
              ),
//              // TODO: github issue
//              ListTile(
//                title: Text('Language'),
//                trailing: DropdownButton(
//                    underline: Divider(thickness: 0, color: Colors.transparent),
//                    value: S.of(context).language,
//                    items: LangCode.allEntries.keys.map((language) {
//                      return DropdownMenuItem(
//                          value: language, child: Text(language));
//                    }).toList(),
//                    onChanged: (language) {
//                      db.userData.language = language;
//                      db.onAppUpdate();
//                    }),
//              ),
              SwitchListTile.adaptive(
                  title: Text('使用移动数据下载'),
                  value: db.userData.useMobileNetwork ?? false,
                  onChanged: (v) async {
                    db.userData.useMobileNetwork = v;
                    await db.checkNetwork();
                    setState(() {});
                  }),
            ],
          ),
          TileGroup(
            header: 'About',
            children: <Widget>[
              ListTile(
                title: Text('关于Chaldea'),
                onTap: () => SplitRoute.popAndPush(context,
                    builder: (context) => AboutPage()),
              ),
            ],
          ),
          TileGroup(
            header: 'Test(debug mode: ${kDebugMode ? 'on' : 'off'})',
            children: <Widget>[
              SwitchListTile.adaptive(
                  title: Text('允许下载'),
                  value: db.userData.testAllowDownload ?? true,
                  onChanged: (v) async {
                    db.userData.testAllowDownload = v;
                    await db.checkNetwork();
                    setState(() {});
                  }),
              ListTile(
                title: Text('Master-Detail width'),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: db.userData.criticalWidth ?? 768,
                    items: <DropdownMenuItem<double>>[
                      DropdownMenuItem(value: 768, child: Text('768')),
                      DropdownMenuItem(value: 600, child: Text('600'))
                    ],
                    onChanged: (v) {
                      db.userData.criticalWidth = v;
                      db.onAppUpdate();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void deactivate() {
    super.deactivate();
    db.saveUserData();
  }
}
