项目目录说明

lib/
    main.dart/
        main
            main()
                负责启动 Flutter、初始化桌面窗口、创建仓库和加密服务、启动应用

    app.dart/
        PasswordApp
            build()
                负责构建应用根节点、主题和启动流程入口

    models/
        app_models.dart/
            AppSection
                页面分区枚举，对应密码 / 密码生成 / 同步 / 设置四个主页面

            WebsiteEntry
                color
                    负责把 colorValue 转成 Flutter Color 供 UI 使用

            AccountEntry
                负责账号展示数据，包含账号 id、所属网站、标签、账号名、密码

            RecycledAccountEntry
                负责回收站账号数据，包含回收记录、原账号、网站 id、网站名、账号名、密码、删除时间

            SettingSwitchItem
                负责设置页开关项数据结构

            WebsiteDraft
                负责新增或编辑网站时提交的数据草稿

            AccountDraft
                负责新增或编辑账号时提交的数据草稿
            UserAccountImportResult
                负责返回账号导入后的新增网站、新增账号、更新账号统计结果

    pages/
        dashboard_screen.dart/
            DashboardScreen
                build()
                    负责主页面壳子、左侧导航/抽屉导航、桌面和移动布局切换、密码/密码生成/同步/设置页面切换

        password_generator_page.dart/
            PasswordGeneratorPage
                build()
                    负责创建密码生成页面状态组件

            _PasswordGeneratorPageState
                initState()
                    负责页面首次加载后按默认规则生成密码列表
                dispose()
                    负责释放长度和生成次数输入控制器
                _generatePasswords()
                    负责按当前规则批量生成密码并更新结果列表
                _buildOptions()
                    负责把开关和输入框内容转换成密码生成配置
                _copyPassword()
                    负责复制指定密码并弹出提示
                _showMessage()
                    负责统一显示页面提示消息
                build()
                    负责构建规则配置卡片和生成结果列表 UI

        password_page.dart/
            PasswordPage
                build()
                    负责创建密码首页状态组件

            _PasswordPageState
                initState()
                    负责注册搜索监听和同步事件监听，并首次加载网站数据
                dispose()
                    负责释放搜索控制器和同步订阅
                _handleSearchChanged()
                    负责响应搜索输入变化并刷新列表
                _loadSites()
                    负责按当前搜索条件加载网站和账号数据
                _runSubmission()
                    负责统一执行增删改操作、刷新列表并弹出提示
                _addSite()
                    负责弹出新增网站对话框并保存网站
                _editSite()
                    负责弹出编辑网站对话框并更新网站
                _addAccount()
                    负责弹出新增账号对话框并保存账号
                _editAccount()
                    负责弹出编辑账号对话框并更新账号
                _deleteSite()
                    负责删除网站
                _deleteAccount()
                    负责删除账号
                _openRecycleBin()
                    负责加载回收站数据并打开恢复弹层
                _toggleReveal()
                    负责切换密码明文显示状态
                _copyPassword()
                    负责复制密码并弹出提示
                build()
                    负责构建密码首页整体布局、搜索区、统计区和网站卡片列表

        password_page_sections.dart/
            _MetricBarItem
                build()
                    负责顶部统计条单项 UI

            _WebsiteCard
                build()
                    负责网站卡片、站内账号列表、网站菜单操作 UI

            _AccountTile
                build()
                    负责单个账号卡片、显示/复制/编辑/删除操作 UI

            _InfoRow
                build()
                    负责信息行通用展示 UI

            _EmptyState
                build()
                    负责无数据时的空状态 UI

            _RecycleBinSheet
                build()
                    负责创建回收站弹层状态组件

            _RecycleBinSheetState
                build()
                    负责构建回收站列表和恢复按钮 UI
                _formatDeletedAt()
                    负责格式化删除时间显示文本

        sync_page.dart/
            SyncPage
                build()
                    负责同步页面 UI，包含扫描局域网设备、选择设备同步、手动输入地址同步、监听同步完成提示

        settings_page.dart/
            SettingsPage
                build()
                    负责设置页，包含更新密钥、账号导入导出和查看存储路径
            _SettingsPageState
                _importAccounts()
                    负责弹出导入窗口、解析 JSON 并写入账号数据
                _exportAccounts()
                    负责导出当前可见网站和账号 JSON 到剪切板

    repositories/
        password_repository.dart/
            PasswordRepository
                initialize()
                    负责初始化数据库连接
                fetchSites()
                    负责读取可见网站、解密账号并按搜索条件过滤结果

        password_repository_sync.dart/
            PasswordRepositorySync
                fetchDeletedAccounts()
                    负责读取回收站中的已删除账号并解密密码
                exportPlainSyncData()
                    负责导出网站、账号、历史记录、回收站的明文同步数据
                importPlainSyncData()
                    负责导入外部同步数据
                mergePlainSyncData()
                    负责在事务中合并同步数据
                _mergeSites()
                    负责合并网站同步数据和删除状态
                _mergeAccounts()
                    负责合并账号同步数据和删除状态
                _mergePasswordHistory()
                    负责合并密码历史同步数据
                _mergeAccountRecycleBin()
                    负责合并账号回收站同步数据
        password_repository_user_transfer.dart/
            PasswordRepositoryUserTransfer
                exportUserAccountData()
                    负责导出面向用户的站点和账号 JSON 数据
                importUserAccountData()
                    负责解析用户导入 JSON 并按站点、账号规则合并到数据库
                _parseUserImportPayload()
                    负责校验导入 JSON 结构并转换为内部导入模型

        password_repository_mutations.dart/
            PasswordRepositoryMutations
                addSite()
                    负责新增网站
                updateSite()
                    负责修改网站
                addAccount()
                    负责新增账号并写入密码历史
                updateAccount()
                    负责修改账号并在密码变化时写入历史
                rotateSecretKey()
                    负责轮换密钥并重加密账号、历史和回收站密码
                deleteSite()
                    负责软删除网站并软删除站内账号，同时写入回收站
                deleteAccount()
                    负责软删除单个账号并写入回收站
                restoreAccount()
                    负责恢复账号；若网站不存在则按回收站记录重建网站

        password_repository_helpers.dart/
            PasswordRepositoryHelpers
                _insertPasswordHistory()
                    负责写入密码历史记录
                _generateUuid()
                    负责生成 UUID
                _nowIso()
                    负责生成当前 UTC 时间字符串
                _findRecycleEntryId()
                    负责查找账号对应的回收站记录 id
                _upsertRecycleEntry()
                    负责新增或覆盖回收站记录
                _normalizedTimestamp()
                    负责标准化时间字段格式
                _isIncomingNewer()
                    负责比较同步数据时间先后
                _readBoolFlag()
                    负责把动态值转换为布尔删除标记
                _findSiteNameById()
                    负责按网站 id 查找网站名称

    services/
        app_layout.dart/
            AppLayout
                负责统一管理桌面/移动端宽度断点和窗口最小尺寸规则

        password_generator_service.dart/
            PasswordGeneratorOptions
                normalized()
                    负责标准化密码生成配置中的长度和生成次数默认值及边界

            PasswordGeneratorService
                generateBatch()
                    负责按配置批量生成随机密码

        app_storage_paths.dart/
            AppStoragePaths
                resolveDatabasePath()
                    负责解析数据库文件路径
                resolveKeyFilePath()
                    负责解析密钥文件路径

        database_service.dart/
            DatabaseService
                database
                    负责懒加载数据库连接并处理迁移
                close()
                    负责关闭数据库连接
                _resolveDatabasePath()
                    负责解析数据库实际路径
                _createSchema()
                    负责创建数据库表结构
                _migrateToUuidSchema()
                    负责旧整数主键迁移到 UUID
                _migrateToSoftDeleteSchema()
                    负责迁移账号软删除和回收站表结构
                _migrateToSiteSoftDeleteSchema()
                    负责迁移网站软删除字段和回收站网站名字段
                _tableHasColumn()
                    负责检查表字段是否存在
                _generateUuid()
                    负责生成数据库迁移时使用的 UUID

        password_crypto_service.dart/
            PasswordCryptoService
                encrypt()
                    负责加密密码
                decrypt()
                    负责解密密码
                decryptWithMigrationSupport()
                    负责兼容旧密钥或旧格式解密
                requiresUnlock()
                    负责判断当前是否需要解锁
                unlockWithPassword()
                    负责使用口令解锁
                generateSecretKey()
                    负责生成新密钥
                activateSecretKey()
                    负责激活内存中的密钥
                persistSecretKey()
                    负责持久化密钥到文件

        lan_sync_service.dart/
            LanSyncShareInfo
                负责同步分享信息数据结构

            LanSyncPeerInfo
                负责局域网对端设备信息数据结构

            LanSyncCompletionEvent
                负责同步完成事件数据结构

            LanSyncDiscoveryCandidate
                负责 discovery 阶段候选设备数据结构

            LanSyncService
                _log()
                    负责输出同步日志
                certificateFingerprintForTesting
                    负责暴露证书指纹给测试使用
                multicastAddressForTesting
                    负责暴露组播地址给测试使用
                encodeDiscoveryProbeForTesting()
                    负责构造 discover 探测报文
                encodeDiscoveryResponseForTesting()
                    负责构造 announce 响应报文
                decodeDiscoveryMessageForTesting()
                    负责解析 discovery 报文
                extractPeerCandidatesForTesting()
                    负责从 announce 报文提取候选 peer
                isRunning
                    负责提供服务运行状态
                cachedPeers
                    负责提供当前缓存的 peer 列表
                syncEvents
                    负责暴露同步完成事件流

        lan_sync_service_server.dart/
            LanSyncServiceServer
                startServer()
                    负责启动 HTTPS 同步服务
                stopServer()
                    负责停止 HTTPS 同步服务和 discovery 监听
                syncWithPeer()
                    负责主动向对端发起同步并合并返回数据
                importFromPeer()
                    负责兼容调用方式，内部复用 syncWithPeer
                _currentShareInfo()
                    负责构造当前服务分享信息
                _startServerInternal()
                    负责绑定 HTTPS 服务并处理 export/info/merge 路由
                _stopServerInternal()
                    负责关闭服务、socket、定时器和平台锁
                _buildShareUrls()
                    负责生成当前设备可分享的 export URL 列表
                _fetchPeerName()
                    负责读取对端名称信息
                _buildPeerUri()
                    负责标准化对端地址为同步 URI

        lan_sync_service_discovery.dart/
            LanSyncServiceDiscovery
                discoverPeers()
                    负责发现局域网和模拟器中的同步设备
                _discoverPeersInternal()
                    负责组合组播发现和模拟器发现结果
                _startMulticastDiscoveryListener()
                    负责启动 UDP 组播监听
                _joinDiscoveryMulticastGroups()
                    负责加入组播组
                _handleDiscoveryDatagram()
                    负责处理收到的 discover/announce 报文
                _discoverMulticastPeers()
                    负责发送 discover 探测并等待对端响应
                _startAnnouncementTimer()
                    负责定时广播 announce
                _announcePresence()
                    负责广播或定向发送 announce 报文
                _sendDatagramViaInterfaces()
                    负责通过各网卡发送 UDP 报文
                _registerDiscoveryAnnouncement()
                    负责处理 announce 并探测对端详情
                _mergeCachedPeer()
                    负责合并 peer 缓存
                _probePeer()
                    负责探测单个 peer 的信息接口
                _listSelfAddresses()
                    负责列出本机私有 IPv4 地址
                _listPrivateIpv4Interfaces()
                    负责列出含私有 IPv4 的网络接口
                _comparePeerHosts()
                    负责按优先级比较 host 顺序
                _hostPriority()
                    负责计算 host 优先级
                _discoverEmulatorPeers()
                    负责通过 adb 发现 Android 模拟器中的同步设备

        lan_sync_service_platform.dart/
            LanSyncServicePlatform
                _getDeviceName()
                    负责缓存并返回设备名
                _resolveDeviceName()
                    负责从平台或 hostname 推断设备名
                _acquirePlatformMulticastLock()
                    负责在 Android 上申请 multicast lock
                _releasePlatformMulticastLock()
                    负责在 Android 上释放 multicast lock
                _resolveAdbPath()
                    负责查找 adb 可执行文件路径

        lan_sync_service_helpers.dart/
            LanSyncServiceHelpers
                _emitSyncEvent()
                    负责派发同步完成事件
                _normalizeSyncSourceName()
                    负责标准化同步来源名称
                _normalizeExportPath()
                    负责标准化导出路径
                _normalizePeerName()
                    负责标准化 peer 显示名称
                _isGenericPeerName()
                    负责判断名称是否是通用占位名称

            顶层辅助函数
                _extractPeerCandidates()
                    负责从 announce 报文中提取候选 peer
                _coercePort()
                    负责把动态端口值转换为 int
                _coerceHosts()
                    负责把动态 hosts 转换为字符串列表
                _isPrivateIpv4()
                    负责判断 host 是否为私有 IPv4
                _normalizeExportPathStatic()
                    负责静态标准化 export path
                _buildInstanceId()
                    负责生成服务实例 id
                _buildRequestId()
                    负责生成 discovery 请求 id

    widgets/
        side_navigation.dart/
            SideNavigation
                build()
                    负责左侧导航菜单和页面切换入口

        site_form_dialog.dart/
            SiteFormDialog
                build() 负责创建新增/编辑网站对话框

            _SiteFormDialogState
                initState()
                    负责初始化标题和域名输入框
                dispose()
                    负责释放输入控制器
                build()
                    负责构建标题和域名输入表单并提交 WebsiteDraft
                _pickColor()
                    负责按标题生成稳定的默认颜色

        account_form_dialog.dart/
            AccountFormDialog
                build()
                    负责创建新增/编辑账号对话框

        account_import_dialog.dart/
            AccountImportDialog
                build()
                    负责创建账号 JSON 导入对话框并收集导入文本
        memo_dialog.dart/
            MemoDialog
                build()
                    负责创建新增/查看备忘录弹窗，展示完整内容并支持直接编辑保存

models/
    app_models.dart/
        MemoEntry
            负责备忘录展示数据，包含 id、content、updatedAt
        MemoDraft
            负责新增或编辑备忘录时提交的草稿数据

repositories/
    password_repository_memos.dart/
        PasswordRepositoryMemos
            fetchMemos()
                负责按更新时间倒序读取全部备忘录
            addMemo()
                负责新增备忘录
            updateMemo()
                负责更新备忘录内容和更新时间
            deleteMemo()
                负责删除指定备忘录

    pages/
        memo_page.dart/
            MemoPage
                build()
                    负责构建备忘录页面整体布局、顶部统计、添加按钮和备忘录列表
            _MemoPageState
                initState()
                    负责首次加载备忘录数据
                _loadMemos()
                    负责读取全部备忘录并刷新页面状态
                _addMemo()
                    负责打开新增备忘录弹窗并保存新内容
                _viewMemo()
                    负责打开查看弹窗、展示完整内容并保存编辑
                _deleteMemo()
                    负责删除备忘录并刷新列表
android/
    app/
        src/main/kotlin/com/example/password_app/MainActivity.kt/
            MainActivity
                configureFlutterEngine()
                    负责注册平台通道方法
                getDeviceName 相关逻辑
                    负责返回 Android 设备名称
                multicast lock 相关逻辑
                    负责申请和释放 Android multicast lock
