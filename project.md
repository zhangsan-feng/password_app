# Project Files Summary

## App Entry

- `lib/main.dart`
  负责启动 Flutter、初始化桌面窗口、创建仓库和加密服务、启动应用。

- `lib/app.dart`
  负责应用根节点、主题、启动流程、解锁流程、初始化仓库和同步服务。

## Layout

- `lib/services/app_layout.dart`
  负责统一管理桌面/移动端宽度断点和窗口最小尺寸规则。

- `lib/pages/dashboard_screen.dart`
  负责主页面壳子、左侧导航/抽屉导航、根据宽度切桌面或移动布局、切换密码/同步/设置页面。

- `lib/widgets/side_navigation.dart`
  负责左侧导航菜单和页面切换入口。

## Password Module

- `lib/pages/password_page.dart`
  负责密码首页，包含网站列表、账号列表、搜索、顶部操作栏、增删改网站和账号、回收站、同步后刷新 UI。

- `lib/widgets/site_form_dialog.dart`
  负责新增/编辑网站弹窗。

- `lib/widgets/account_form_dialog.dart`
  负责新增/编辑账号弹窗。

- `lib/models/app_models.dart`
  负责定义网站、账号、回收站、草稿数据结构。
  - `AppSection`
    页面分区枚举，对应密码 / 同步 / 设置三个主页面。
  - `WebsiteEntry`
    网站展示数据，对应网站表的一条记录，包含网站 `id`、名称、域名、颜色，以及它下面的账号列表。
  - `AccountEntry`
    账号展示数据，对应账号表的一条记录，包含账号 `id`、所属网站 `siteId`、标签、账号名、密码。
  - `RecycledAccountEntry`
    回收站账号数据，对应账号回收站查询结果，包含回收记录 `id`、原账号 `accountId`、所属网站 `siteId`、账号名、密码、删除时间。
  - `SettingSwitchItem`
    设置项开关数据，目前是简单的标签 + 开关状态结构。
  - `WebsiteDraft`
    新增/编辑网站时提交用的数据草稿，包含名称、域名、颜色。
  - `AccountDraft`
    新增/编辑账号时提交用的数据草稿，包含所属网站 `siteId`、标签、账号名、密码。


- `lib/repositories/password_repository.dart`
  负责数据库读写、密码解密/加密衔接、网站账号查询、搜索、同步数据导入导出与合并。

## Sync Module

- `lib/pages/sync_page.dart`
  负责同步页面 UI，包含扫描局域网设备、选择设备同步、手动输入地址同步、监听同步完成提示。

- `lib/services/lan_sync_service.dart`
  负责局域网同步核心逻辑，包含 HTTPS 同步服务、UDP 组播发现、设备广播、扫描、发起同步、接收同步、同步事件通知。

## Settings Module

- `lib/pages/settings_page.dart`
  负责设置页，包含更新秘钥和查看存储路径。

## Storage / Crypto

- `lib/services/password_crypto_service.dart`
  负责密码加密、解密、解锁等安全逻辑。

- `lib/services/database_service.dart`
  负责数据库初始化和数据库连接。

- `lib/services/app_storage_paths.dart`
  负责数据库和秘钥文件路径解析。

## Android Native

- `android/app/src/main/kotlin/com/example/password_app/MainActivity.kt`
  负责 Android 原生侧的局域网同步辅助逻辑，包括组播锁和设备名称获取。

## Localization

- `lib/l10n/*`
  负责多语言文案定义和生成结果。


# 新的需求
1. 给网站表 新增is_delete 字段 用于同步使用 同时修改同步数据的的逻辑
2. 给账号回收站表新增一个记录网站的字段  回收站还原账号的时候 网站不存在就创建 存在就直接还原 
