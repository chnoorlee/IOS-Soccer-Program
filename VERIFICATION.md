# SportsHub 当前验证记录

> 最近运行日期：2026-08-08  
> 环境：Windows PowerShell；无 Swift、Xcode、`xcodebuild` 或 XcodeGen

## 已执行

### 工程静态检查

命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-scaffold.ps1
```

结果：PASS

- 必需文件：179
- App 双语键：885，Arabic/English 集合一致且无重复
- 直接本地化初始化键：411，均能在资源中找到
- 被检查的 App 与 Widget Swift 文件：108
- Accessibility identifiers：340
- Accessibility labels：45
- 未发现参考 App 品牌混入 Swift 源码
- 未发现硬编码网络 URL、`try!`、`as!`、`fatalError`、`TODO` 或 `FIXME`
- App 与 Widget 的 Info.plist XML 可以解析
- `SportsDataMode`、`SportsAPIBaseURL`、`SportsAuthEnabled`、`SportsPublicWebBaseURL`、`SportsMediaAllowedHosts`、`SportsCommunityEnabled`、社区规范/发布方支持 URL、五项订阅/广告发布设置、本机 URL scheme、Sign in with Apple/APNs entitlement、Debug/Release APNs 环境设置与 API 契约标记存在；公开域名、媒体主机、订阅产品和法律链接在未获配置时保持空值，广告保持关闭

### Swift AST 语法解析

工具：`ast-grep 0.45.0` 内置 Swift tree-sitter 语法，安装在工作区外的 npm 缓存。

结果：PASS

- 解析范围：App、Widget、单元测试和 UI 测试
- Swift 文件：155
- Tree-sitter `ERROR` 节点：0

此检查能发现源代码语法树错误，但不能解析 Apple SDK 类型或替代 Swift 编译器。

### 首页可解释聚合

冻结规则见 `EXPLAINABLE-HOME-CONTRACT.md`。纯映射测试源码覆盖球队、赛事、两者同时命中、球员不得推断赛程、零关注公共回退，以及相关/公共赛程完整且互斥的分区。首页使用三类关注快照作为直达入口，每张相关比赛显示可审计原因，文章区改为“最新新闻”；大字号把兴趣和比赛横轨切换为纵向，账号切换时先隐藏旧兴趣并等待当前身份同步。UI 旅程源码覆盖球员+赛事兴趣、赛事原因、零关注和公共新闻语义。以上已通过 Windows 静态检查与 Swift AST，尚未由 XCTest、模拟器、RTL、Dynamic Type 或 VoiceOver 真机执行。

### 首页新闻发现

冻结规则见 `HOME-NEWS-DISCOVERY-CONTRACT.md`。纯映射测试源码覆盖分类首次出现顺序、全部分类保持 Provider 顺序、精确分类过滤、失效选择归一化、空源、首条/其余文章无重复分区，以及收藏源不与公开源互相推断。首页提供“全部/已收藏”与当前载荷真实分类控件，首条仅使用视觉层级而不宣称热门、独家、推荐或精选；收藏加载/空/失败独立于公开首页，收藏通知触发重载，账号切换立即清空旧收藏并作废旧请求。辅助功能字号将范围与分类变为纵向 44pt 按钮，选择同时使用图标和 selected trait。UI 测试源码覆盖空收藏、Statistics 精确筛选，并把既有文章收藏旅程扩展到 Home Saved 范围。以上已通过 Windows 静态检查与 Swift AST；Swift 类型检查、XCTest、模拟器布局、RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 结构化文章 Visual Brief

冻结规则见 `ARTICLE-VISUAL-BRIEF-CONTRACT.md`。领域模型与 OpenAPI 区分普通文章和 Visual Brief；详情结构只接受 1...4 个有序区块、每区 2...6 项，对比区块必须恰好两项，区块 ID 与全篇项目 ID 必须唯一。双语标题、数值、标签、说明和数据说明均有长度/控制字符边界，载荷不接受 HTML、SVG、URL 或远程媒体。格式与详情不匹配会在公共缓存写入前失败；旧收藏缺失格式时迁移为普通文章。Mock `article-2` 使用明确声明为虚构的五个指标。

单元测试源码覆盖旧收藏迁移与再编码、顺序保持、格式/载荷错配、对比数量、四区上限、跨区重复 ID、长度和控制字符；Remote 测试覆盖完整 VISUAL_BRIEF 映射以及缺失结构时缓存零写入。UI 旅程源码从首页 Statistics 精确筛选进入 `article-2`，定位 Visual Brief、区块和项目。组件使用语义文本、标题 trait、图标+文字格式标签、leading/trailing RTL 布局和辅助功能字号单列重排。以上仍需 macOS/Xcode 的 Swift 类型检查、XCTest、模拟器 RTL/Dynamic Type、VoiceOver 朗读和真实视觉验收。

### 文章卡公开互动摘要

冻结规则见 `ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md`。文章摘要新增可空、观看者无关的 `engagement` 快照，只包含 `totalReactions` 与 `publishedComments`，二者限制为 0...2,000,000,000；当前 OpenAPI 响应要求该对象，iOS 在滚动发布和旧收藏中仍容忍缺失并隐藏区域，绝不把未知值伪装成零。公共计数沿用文章 ETag/离线缓存且不标为实时；文章详情社区继续独立 `no-store`，个人反应、待审/拒绝/移除评论、屏蔽状态、排行信号和分享分析均未混入公开卡片，也不影响新闻顺序。Mock 的 202 次反应与 3 条已发布评论由现有反应分项和审核评论目录交叉约束。

契约测试源码覆盖精确映射、旧载荷/收藏迁移、负数、上限溢出和损坏持久化快照；Remote 测试证明非法计数在公共缓存写入前失败，UI 旅程断言英语文章卡合并后的辅助功能标签包含两个完整计数短语。原创摘要使用现有 SportsHub 青色/暖金语义、颜色之外的文字、地区化数字和 Dynamic Type 纵向重排；只读计数合并为一个语义摘要，外层文章卡仍是唯一导航目标，详情页的原生分享入口保持独立。Windows 静态、Swift AST 与 OpenAPI 校验已通过；Swift 类型检查、XCTest、实际卡片布局、Arabic RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode/模拟器或真机。

### 文章授权主图

冻结规则见 `ARTICLE-HERO-MEDIA-CONTRACT.md`。当前 `ArticleSummary.heroMedia` 必须在现行响应中显式为授权元数据对象或 `null`，滚动客户端仍容忍缺失并保留原创封面。DTO 在公共 ETag 缓存写入前校验 2,048 字符以内的无凭证/无端口/无片段 HTTPS 直链、五种精确图片 MIME、640...4,096 尺寸、16MP 上限、1.2...2.4 比例、双语替代文本和双语可见署名。Mock 两篇文章均明确为 `nil`，没有复制第三方图片；个人收藏编码继续排除整个媒体对象和签名 URL。

独立媒体会话按 `SportsMediaAllowedHosts` 精确主机失败关闭，禁用 Cookie 与 URL credential storage，不发送 Bearer，拒绝重定向；HTTP 200、MIME、已知 Content-Length 在读取前验证，未知长度在流式读取时以 8 MiB 停止。ImageIO 在 UIKit 展示前核对真实像素并在独立 actor 中生成分场景缩略图，避免文章流保留整批 16MP 位图；取消/重试以加载 UUID 防止旧请求覆盖新状态。卡片图片为装饰并维持整卡单一导航，详情才朗读替代文本、显示署名，并在真实失败时给出文字状态和 44pt 重试。

契约测试源码覆盖精确映射、缺失/null 迁移、ID/URL/MIME/尺寸/像素/比例/文字拒绝、收藏无媒体序列化、精确主机/后缀攻击、未知/超大响应、状态/MIME/空体、重定向拒绝，以及真实 PNG 的类型/像素核对和下采样；Remote 测试证明非法媒体在缓存写入前失败，UI 旅程证明 Mock 缺图不被误报成加载失败。Windows 静态闸门、155 个 Swift 文件的 0 个 AST 错误节点、两个 plist 解析和 Redocly OpenAPI 校验已通过；`SPORTS_MEDIA_ALLOWED_HOSTS` 仍为空，因此当前没有真实 CDN 请求。Swift 6 类型检查、XCTest、URLSession/缓存实际行为、真实图片解码、列表内存、Arabic RTL、Dynamic Type、VoiceOver 和视觉裁切仍待 macOS/Xcode/模拟器或真机。

### 首页比赛状态筛选

冻结规则见 `HOME-MATCH-FILTER-CONTRACT.md`。纯模型测试源码覆盖全部状态保持原分区/顺序/关注原因，直播合并进行中和中场，载荷驱动的固定选项顺序，延期/取消等精确状态，失效选择归一化，筛选后分区完整互斥，以及空输入。Home 的一个控件同时过滤关注相关和公共比赛，不计算热门或重要度；仅显示载荷实际包含的状态，刷新提交新 feed 前会把已消失的选择归一化为全部。有关注对象但筛选后无相关比赛时使用专用空态。辅助功能字号将横向轨改为纵向 44pt 按钮，选择同时使用勾选图标和 selected trait。UI 测试源码覆盖 Live → Upcoming 切换，并断言复用原 fixture ID。以上已通过 Windows 静态检查与 Swift AST；Swift 类型检查、XCTest、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 比赛发现与赛事分组

冻结规则见 `MATCHES-DISCOVERY-CONTRACT.md` 与 `MATCHES-DATE-SEARCH-CONTRACT.md`。纯模型测试源码覆盖赛事首次出现顺序、赛事列表在直播筛选下保持稳定、进行中/中场合并、状态与赛事组合过滤、失效赛事选择归一化、首个赛事快照命名、分组完整互斥、三种可达空态，以及有赛事但无直播时保留用户选择；日期模型另覆盖 DST 转换期间连续五个本地日、轨内选择保持中心、任意日期重新居中，以及相对日期必须依据真实今天。搜索模型覆盖空/过短/无结果/有结果状态、英文大小写、阿拉伯文附加符号和 Alef 变体、双方队名与缩写、赛事、场馆、稳定顺序和去重。Matches 页面提供五日轨、任意日期图形 DatePicker、全部/直播、载荷驱动赛事筛选、按赛事分组，以及仅作用于当前组合筛选结果的本地搜索；搜索不调用全站接口或逐场联网，结果复用原 fixture ID。辅助功能字号把日期、状态和赛事轨改为纵向 44pt 按钮，日历/搜索动作、搜索状态和清除动作均有双语语义及稳定标识。UI 测试源码覆盖五个日期、两个赛事组、杯赛/Live 组合、日历打开/Today/Apply、搜索原比赛 ID 和无结果状态。最终静态计数与回归结果见本文件顶部；类型检查、XCTest、图形 DatePicker、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 比赛关注范围

冻结规则见 `MATCHES-FOLLOWING-CONTRACT.md`。首页与 Matches 现在共用同一个纯 `FixtureFollowMatcher`：只允许已关注主/客队和赛事 ID 命中，原因严格区分球队、赛事和两者同时命中，球员关注不会推断参赛。比赛呈现测试源码覆盖共享匹配器、全部范围向后兼容、关注范围的稳定组内顺序、直播/赛事组合、整日赛事轨稳定、只关注球员的专用空态，以及有可匹配关注但当前筛选无结果的两个上下文空态。Matches 在当前身份关注同步完成前禁用关注范围；认证变化会先将 `followLoadRequestID` 置空、清除 `followsReady` 并回到全部，再以请求 ID 守卫恢复，普通关注更新则由 `AppModel.orderedFollows` 直接重算而不重置筛选。同步失败不会伪装成零关注，而会保持全部比赛可用、禁用关注范围、把 VoiceOver 焦点移到双语错误并提供 44pt 重试。每张关注比赛和其作用域搜索结果都保留双语文字原因；大字号把全部/关注按钮改为纵向 44pt 布局。UI 测试源码完成首启关注球队 → Matches 关注范围 → 只见原相关 fixture ID/原因 → 叠加 Live 的旅程。缺少供应商排名字段的 Top/热门范围没有被伪造。以上通过 Windows 静态检查与 Swift AST；身份竞态、Swift 类型检查、XCTest、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 情境化提醒入口

冻结规则见 `CONTEXTUAL-ALERTS-CONTRACT.md`。纯展示模型测试源码覆盖复合类型+ID 的精确实体资格、三类关注对象、球队/赛事/组合比赛原因、球员关注不得推断比赛，以及零关注不合资格。球队、球员和赛事详情提供纵向 44pt 入口，比赛中心只在权威 fixture 加载后提供工具栏铃铛；面板对不合资格实体提供一个关注选项，对比赛固定提供主队、客队和赛事三个纵向选项。关注成功后才复用同一个 `NotificationSettingsCard`，并明确所有事件类别仍对全部关注全局生效；打开面板或关注对象均不调用 `requestAuthorization()`。UI 测试源码覆盖首启关注球队 → 球队详情资格与访客账号边界 → 相关比赛的球队命中原因，并断言访客看不到通知启用按钮。以上通过 Windows 静态检查；Swift 类型检查、XCTest、真实 sheet、系统权限界面、RTL、Dynamic Type、VoiceOver 和 APNs 收件仍待 macOS/Xcode/真机。

### 赛事赛季赛程

冻结规则见 `COMPETITION-FIXTURES-CONTRACT.md`。赛事详情现在只加载当前选择的积分榜、榜单或赛程标签；切换赛季、标签或榜单类别时使用完整请求身份和 UUID 双重守卫，旧响应不能回写。赛程 Remote provider 要求赛事/赛季回显一致、每页不超过 100、总量不超过 1,000、跨页 kickoff+ID 全局正序、ID 全局唯一，并在缓存提交前验证 `hasMore`/`nextCursor` 的终止与非循环语义。纯展示测试覆盖直播/中场、未开赛、已结束、延期、取消的完整互斥分组及正反序；Remote 测试覆盖两页成功、错配不缓存、无序第二页不缓存、跨页重复拒绝及第二页网络故障整份回退到 Mock；UI 旅程用稳定 ID 进入赛事详情赛程并打开原比赛中心。标签具备 44pt、图标+文字、selected trait、RTL 逻辑顺序和辅助功能字号纵向布局，加载失败迁移 VoiceOver 焦点。以上为源码、AST 和静态契约证据；Swift 类型检查、XCTest、模拟器布局、RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 视频编辑发现与资料库

冻结规则见 `VIDEO-DISCOVERY-CONTRACT.md`。新增 `/videos/discovery` 原子快照和独立新鲜度资源：最多 100 条视频必须具有唯一 ID 与权威 sport，可空精选 ID 和最多 10 条有序 Trending ID 必须引用载荷、彼此唯一且精选与 Trending 互斥，所有规则在缓存写入前验证。Remote 测试源码覆盖专用路径、ETag/304、精确映射、悬空引用不缓存和网络故障整份回退；DTO 测试覆盖空载荷、重复项目、悬空精选、重复/悬空 Trending、表面重叠及 100/10 上限。纯展示测试覆盖明确 hero/排名、运动固定顺序、sport+type 交集、失效选择归一化、Provider 顺序以及筛选不得改写全局编辑面或播放权；原有五类频道与 1,000 条分页完整性测试继续保留。Explore 使用原创渐变和 SF Symbols 呈现精选、带文字名次的 Trending、All/Football/Basketball/Esports 等载荷真实分类；常规字号使用横轨，辅助功能字号改为纵向 44pt 控件和排名卡，精选小号文字已按暖金最差背景使用实心白色以守住 4.5:1 对比度。Mock 仍是无受保护媒体的虚构不可播放元数据。UI 旅程覆盖精选、第一名、Esports 精确过滤、Live/Highlights 和受限详情。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、模拟器手势、RTL、Dynamic Type、实际颜色渲染和 VoiceOver 仍待 macOS/Xcode。

### Arabic-first 全局搜索

冻结规则见 `ARABIC-SEARCH-CONTRACT.md`。新增独立 Arabic 正规化器和纯展示层：Mock 匹配去除变音与 tatweel、统一 Alef 变体和 Alef Maqsura，同时明确不音译、不混同 Taa Marbuta；确定性顺序只用于虚构演示。Remote `/search` 继续发送用户修剪后的原文并固定首批 `limit=100`，响应在缓存前拒绝超过 100 条、重复 type+entityId、不安全 ID，以及不一致的 `hasMore`/`nextCursor`。搜索因缺少逐响应来源面板而禁用静默 stale-if-error 和恢复性 Mock 回退，弱网进入可重试错误态。All 范围原样保留服务端顺序，各类型范围只保留有序子序列；失效范围归一化为 All。页面源码覆盖 2–100 字符门禁、350ms 防抖、请求 UUID 防旧响应回写、比分牌式原查询/已加载数量、常规字号横轨、辅助功能字号纵向 44pt 控件、失败焦点和完成 VoiceOver 公告。单元测试源码覆盖正规化边界、四级 Mock 匹配、顺序/范围、复合 ID、重复/超限/游标/不安全 ID 失败，以及远程故障不得转成虚构命中；Remote 测试覆盖原文修剪、路径、100 上限参数、过长查询联网前拒绝和网络故障不得返回未标示旧快照；UI 旅程覆盖摘要、范围轨、球员范围和原结果导航。代码审查又修复了 Mock 长度契约漂移、取消错误可能卡住加载、空结果缺失已加载数量、无目录快照赛事不可导航、大字号摘要/副标题压缩，以及小号文字最差颜色对比。当前只证明源码和静态合同；搜索召回/延迟、Swift 类型检查、XCTest、RTL、Dynamic Type、VoiceOver 与真实服务端排序仍待 macOS/Xcode/授权 Provider。

### 视频详情编辑上下文

冻结规则见 `VIDEO-DETAIL-EDITORIAL-CONTRACT.md`。详情响应新增可空双语出版方、可空节目和最多 10 条完整相关推荐；响应 ID 必须精确回显路径 ID，相关 ID 唯一且不得自引用，数组顺序完全由服务端负责，每条相关视频继续保留自身 `isPlayable`/`availabilityReason`。违约响应在公共缓存写入前拒绝。页面保留既有收藏与权利检查，新增“关于此视频”元数据卡、四行长简介的 44pt Show more/Show less 控件和有序相关推荐导航；短简介即使在大字号换行超过四行也不被永久截断。Mock 的节目、出版方与关系均是原创虚构数据，且全部不可播放。DTO/Remote/Mock/UI 测试源码覆盖精确映射、顺序与权限、路径错配不缓存、重复/自引用/10 条上限、折叠阈值和页面标识。代码审查发现并修复了短简介在辅助功能字号下可能被无按钮截断的问题。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、真实导航、RTL、Dynamic Type、VoiceOver 和媒体播放仍待 macOS/Xcode/模拟器或真机。

### 节目与分集中心

冻结规则见 `VIDEO-PROGRAM-HUB-CONTRACT.md`。新增 `/video-programs` 与 `/video-programs/{programId}` 两个公共资源：每页 1...50 项、游标最长 2,048 字符，目录运动筛选由服务端重新作用域，详情必须精确回显节目 ID；双语标题/描述、显式可空精选视频/发布日期、页内与跨页唯一 ID、`hasMore`/游标组合及嵌套视频权利在缓存前失败关闭。首屏恢复性故障只允许整份切换到具名虚构 Mock 并终止分页，后续页绝不把 Mock 追加到真实数据。

Explore 现有原创深墨节目架入口、运动文字+图标筛选、常规字号双列/辅助功能字号单列卡片、独立初始/刷新/后续页错误和节目详情分集导航；视频详情的节目字段也成为精确 ID 导航。节目对象不制造 Logo、主持人、季数、排播、赞助或商标，Mock 四个节目及其分集全部虚构、不可播放且无第三方图片。契约/Remote/Mock/UI 测试源码覆盖映射、显式空值、文字边界、重复/错配/游标、路径与查询、真实 `200 + ETag → 304` 重验证、缓存前拒绝、运动筛选、首屏整份回退/后续页禁止混入 Mock、分集关系及 Explore → 节目 → 分集 → 受限视频旅程。代码复审另修复了节目 ID Schema 漂移、`hasMore`/游标条件未被 OpenAPI 表达、精选视频缺少可读语义，以及详情状态复用可能短暂显示旧节目。Windows 静态闸门通过：185 个必需文件、908 个双语共享键、428 个本地化初始化键和 110 个产品 Swift 文件；本轮改动的 16 个 Swift 文件由 tree-sitter 解析为 0 个错误/缺失节点。OpenAPI 已由 Redocly 验证为 55 条路径、69 个操作、148 个 Schema，并保留既有 12 条非阻断 4xx 风格警告。Swift 类型检查、XCTest、真实 Provider 完整性、RTL、Dynamic Type、VoiceOver 和节目媒体权利仍待 macOS/Xcode、授权后端与真机。

### 球队上一场/下一场与内容上下文

冻结规则见 `TEAM-CONTEXT-CONTRACT.md`。球队详情响应在缓存前校验路径球队回显、嵌入比赛球队快照一致性、每场恰好包含当前球队、赛事引用、最多 10 场窗口、唯一且跨窗口互斥 ID，以及下一场 kickoff+ID 正序和赛果倒序；直播不会伪装成上一场。球队详情和独立 `/teams/{teamId}/content` 都是 ETag/可见新鲜度资源；内容响应要求 teamId 回显，最多 10 条唯一新闻和视频，新闻按发布时间/ID 稳定倒序，视频保留 Provider 编辑顺序且不制造播放权。页面并发加载球队核心与内容，阵容/内容失败互不遮挡，并用请求 UUID 防止旧球队响应回写；上一场、下一场、新闻和视频均有独立空态与稳定辅助功能标识。Mock 为首支球队提供一场可进入原比赛中心的次日赛程、一条原创虚构新闻和两条不可播放视频元数据；其他球队不靠文本匹配生成内容。单元/Remote/UI 测试源码覆盖空槽、额外窗口、冲突球队快照、无序窗口、文章无序、视频重复、teamId 错配不缓存、ETag/304、球队与内容各自精确的 fallback 新鲜度，以及从 Explore 进入球队页后定位前后比赛/新闻/视频。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 赛事与球员近期内容

冻结规则见 `ENTITY-EDITORIAL-CONTENT-CONTRACT.md`。新增 `/competitions/{competitionId}/content` 与 `/players/{playerId}/content` 两个独立、可 ETag 重验证且 stale-if-error 为 15 分钟的公共资源；DTO 必须精确回显路径 ID，每类最多 10 个唯一项目，文章按发布时间倒序和 ID 正序 tie-break，视频保持 Provider 编辑顺序，所有规则在缓存写入前完成。客户端不按实体名称、球队、统计、标题或描述推断关联，视频元数据继续保留逐条权利状态且不授予播放。赛事详情新增不依赖赛季的“最新”，无赛季时仍可用；球员内容位于统计与转会之间，核心、转会和编辑内容各自使用请求 UUID 与独立失败/重试。共享双轨页面用青色新闻轨与暖金视频轨、图标+文字、独立空态、44pt 导航目标和可见新鲜度表达状态。

契约测试源码覆盖两种实体的成功映射、精确作用域错配、文章/视频各自 10 项上限、重复 ID、文章乱序与同时间 ID tie-break；Remote 测试覆盖两条精确路径、播放器无关的元数据映射、ETag/304、资源新鲜度和错配赛事回显缓存零写入；Mock/fallback 测试覆盖固定 ID 关系、独立空态与精确 `demoFallback`。UI 旅程源码分别定位赛事和球员的新闻/视频轨及稳定项目 ID。代码审查另外修复了球员内容重试曾会重载核心/转会、第四个赛事标签在窄屏 UI 测试中可能需要水平滚动、两类内容错误焦点，以及视频超限测试遗漏。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、模拟器导航、Arabic RTL、Dynamic Type、VoiceOver、真实 CMS 关系、来源标记和媒体授权仍待 macOS/Xcode/授权 Provider。

### 关注球队赛程看板

冻结规则见 `FOLLOWING-TEAM-DASHBOARD-CONTRACT.md`。Following 以一次逻辑请求加载最多 100 支关注球队，并按每批 20 个 `teamId` 调用公共 `/teams/match-snapshots`，避免逐队 N+1；超过上限的关注仍以基础卡片保留导航和取消关注能力。响应必须与请求数量、顺序和球队 ID 完全一致；上一场仅允许已结束，下一场仅允许未开赛，两个槽位的比赛 ID 互斥且嵌入球队快照必须精确一致。任何批次失败都不会返回部分看板；ETag 缓存只在 DTO 与领域契约通过后写入，多批次在线/重验证/离线状态按最差来源汇总，防止后一批掩盖离线数据。页面有独立加载、错误、重试、空槽、新鲜度、身份切换和请求 UUID 边界；卡片在辅助功能字号下纵向排列，状态不只依赖颜色，并可用原 fixture ID 进入比赛中心。单元、Remote、Mock 与 UI 测试源码覆盖顺序、可空槽、错误状态、快照冲突、20 项分批、重复 ID 联网前拒绝、错序不缓存、混合批次离线汇总，以及 Following → 上一场/下一场 → Match Center 旅程。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

### 免费非博彩小组排名预测

冻结规则见 `PREDICTION-GAMES-CONTRACT.md`。首页新增独立公共预测区；远程游戏在缓存前校验最多 20 场、HTTPS 规则链接、1...12 个有序分组、组/队唯一性、每组 2...8 队及合法晋级位。草稿保持 Provider 顺序，使用至少 44pt 的上下按钮逐位调整，晋级状态同时以文字和图标表达；辅助功能字号改为纵向布局。个人条目要求 Sign in with Apple 账户，GET/PUT 均为 Bearer `no-store`，PUT 使用幂等键并提交每组每队恰好一次的完整顺序；响应必须精确回显游戏和提交顺序。服务器 `state` 与 `lockAt` 最终裁决写入，409 会把页面转为只读。认证切换不仅通过账号 ID 与请求 UUID 丢弃旧响应，还将令牌查询绑定到发起操作时捕获的账号 ID；身份不匹配会在联网前失败，避免旧草稿写入新账户。公开故障可具名回退虚构游戏，但个人条目绝不回退。

新增模型/DTO/Mock/Remote 测试源码覆盖默认顺序、边界移动、组顺序与完整排列、HTTPS 规则、重复游戏、错误游戏回显、锁定写入拒绝、Mock 往返、公共 ETag/304、新鲜度、404 空条目、无令牌发网前拒绝、Bearer/`no-store`/幂等头、精确请求体和错误响应拒绝。UI 旅程源码覆盖游客进入虚构免费挑战、把第二队上移到第一位、边界按钮禁用且不出现保存入口。以上通过 Windows 静态检查、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、真实账户、服务器时钟、模拟器 RTL/Dynamic Type 和 VoiceOver 仍待 macOS/Xcode/真实后端。

### 地区化播出指南

冻结规则见 `BROADCAST-GUIDE-CONTRACT.md`。比赛载荷的可空 `broadcasts` 在旧缓存中缺失时映射为空，新快照显式写回数组；Remote DTO 在缓存前校验最多 12 条、两位大写地区码、双语频道、成对可空双语解说、规范音频语言、Provider 顺序和规范化去重，延期/取消比赛拒绝残留排期。比赛卡只显示首个频道与额外数量，比赛中心 Summary 使用无动画的信号轨展示全部地区、频道、解说和音频语言，同时明确频道元数据不授予订阅或播放权；空数据不被称作“没有转播”。Mock 使用两个原创虚构频道，不含 URL 或真实商标。

新增契约/Remote/UI 测试源码覆盖 Provider 顺序、本地化字段、可空解说、缺失字段与旧 Codable 快照迁移、地区/语言精确格式、文本上限/控制字符、规范化重复、13 条超限、取消/延期拒绝、违约响应缓存写入前失败，以及赛事详情进入比赛中心后定位完整播出指南。代码审查修复了大字号频道摘要截断、语言测试误改本地化字段名、代码字段空格被静默接受，以及 OpenAPI 未表达转播文本上限的问题。以上已通过 Windows 静态检查、Swift AST 冒烟检查与 OpenAPI 校验；Swift 类型检查、XCTest、缓存迁移实跑、Arabic RTL、Dynamic Type、VoiceOver、真实地区识别、频道排期和版权仍待 macOS/Xcode/授权供应商。

### 审核式文章社区

冻结规则见 `ARTICLE-COMMUNITY-CONTRACT.md`。模型/DTO/Provider/UI 源码覆盖三类反应、仅公开 `PUBLISHED` 评论、待审核提交、五类举报原因与作者屏蔽；评论正文限制 1...500 个 Unicode 字符，只允许换行和制表符控制字符。页内与跨页均校验最新优先顺序、唯一 ID 和非循环游标后才提交 UI。公共和账户社区读取均为 `no-store`，账户写入绑定发起账号和幂等键；Fallback 永不把失败转换成 Mock 社区数据。发布闸门同时存在于 UI 和会话数据路由，账号切换会清空草稿/回执/举报状态并使旧加载、分页和写入结果失效；加载失败显示具名重试，不保留另一文章或身份的社区内容。

Mock 只展示原创虚构评论，默认应用配置关闭生产写入。Release gate 同时要求显式开关、登录、真实 HTTPS 社区规范与发布方支持 URL；评论提交不做乐观公开。单元测试源码覆盖仅公开审核通过内容、精确反应总数、待审往返、举报/屏蔽、禁止 fallback、release gate、Bearer/`no-store`/方法/路径/请求体/状态码，以及令牌账号不匹配时联网前失败。UI 旅程源码覆盖文章详情的锁定提示、具名演示评论与不可用编辑器。本轮只执行静态/AST/OpenAPI 验证；XCTest、模拟器 VoiceOver/RTL、真实审核过滤/队列、封禁/申诉后台、支持 SLA 和 App Store UGC 审核尚未验证。

### 历史赛季档案

冻结规则见 `HISTORICAL-SEASONS-CONTRACT.md`。2026-08-08 重新读取 Apple 官方 Lookup 响应，Jdwal 3.4.7 的当前商店描述仍明确列出 “History seasons & data”，因此该切片有当前公开证据。赛事摘要的赛季目录现最多 50 项；DTO 在分配领域数组前先做上限检查，随后拒绝重复 ID、无效日期、新旧顺序错误，以及 `currentSeasonId` 与唯一 `isCurrent` 标志不一致。客户端不再从孤立 `isCurrent` 标志猜当前赛季，也不补齐或宣称历史档案完整。

赛事详情以原创档案卡展示名称、起止月份和“当前/档案”文字状态；菜单中每个选项也显式带状态，选择目标保持至少 44pt，并在辅助功能字号下纵向布局。切换赛季继续以赛季 ID、标签、榜单类别和请求 UUID 共同隔离响应。Mock 已把 2026–27 当前赛季和 2025–26 档案赛季分开：二者使用不同积分榜、榜单与赛程；档案赛果日期落在对应赛季内、只有完赛状态，并可用原 fixture ID 打开比赛中心及其确认赛季积分榜。

新增 DTO 测试源码覆盖合法目录、重复、倒序、零长度日期、当前标志错配/缺失和 51 项超限；Mock 测试覆盖新旧赛季数据不同、档案赛果范围和比赛中心可寻址；UI 旅程覆盖赛事页选择 2025–26 档案、看到赛果分组并打开原历史比赛。Windows 静态闸门通过：166 个必需文件、874 个双语共享键、407 个本地化初始化键和 103 个产品 Swift 文件；本轮改动的 8 个 Swift 文件由 tree-sitter 解析为 0 个错误节点，两个 plist 可解析。OpenAPI 3.1 经 Redocly 2.12.0 校验有效，仍只有既有 12 条缺少逐操作 4xx 的非阻断警告；PyYAML 确认 53 条路径、123 个 schema 和 `maxItems: 50`。Swift 类型检查、XCTest、菜单实际行为、Arabic RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode/模拟器；真实档案范围和完整性仍待授权 Provider 与覆盖 SLA。

### XcodeGen YAML 解析

工具：`PyYAML 6.0.3`，安装在工作区外的临时目录。

结果：PASS

- `project.yml` 可解析
- 找到 4 个目标：SportsHub、SportsHubWidgets、SportsHubTests、SportsHubUITests
- deployment target 为 iOS 17.0
- SportsHub scheme 包含单元测试和 UI 测试
- 默认数据模式为 `mock`，远程占位地址为 HTTPS `/v1`
- 公开分享 Web 基地址默认留空
- Debug/Release 的 APNs 环境分别解析为 `development`/`production`

### OpenAPI 3.1 校验

工具：`@redocly/cli 2.46.0`，通过工作区外的 npm 缓存执行。

结果：PASS（描述有效，进程退出码 0；仍有 12 条非阻断风格警告）。

- 路径：55
- 操作：69（operationId 唯一）
- Schema：148
- 结构/引用错误：0
- 当前描述包含 562 个内部 `$ref`；Redocly 已完成引用与结构校验
- 风格警告：12，均为既有操作尚未逐项列出具体 4xx 响应；新增社区、转会中心和赛季重要日期操作已列出对应 4xx，统一 `application/problem+json` 模型已经定义
- 本次版本 `2.46.0` 在 Windows 正常退出；不能把 12 条警告写成零警告 lint

### 新增但尚未执行的单元测试

`RemoteSportsDataProviderTests` 已覆盖源码场景：200 映射、ETag/304、网络故障读取最近已验证缓存、坏 JSON 不入缓存、契约错误不回退 Mock、日期/IANA 时区、球队和比赛详情、球队/球员/赛事实体内容回显与缓存拒绝、赛事列表、文章列表/正文、完整视频分页/详情、搜索、球队/球员详情、赛季阵容、转会、赛季重要日期、积分榜和榜单，以及 410 撤回内容不被 Mock 回退复活。深度赛事测试同时断言 `seasonId` 与榜单 `type` 查询参数。

公共数据状态测试源码覆盖：200 成功、304 验证和弱网离线快照的来源转换，坏 JSON 只记录刷新失败，恢复性 Mock 回退明确记录为虚构演示而不是离线缓存，账户首页记录私有实时状态且仍保持 Bearer `no-store`/公共缓存零写入。独立状态仓库测试覆盖乱序更新拒绝、日期与 IANA 时区资源归一化，以及纯 Mock 与远程呈现边界；UI 测试源码断言首页离线快照标识存在且不会同时宣称演示数据。首页、比赛、新闻、视频列表/详情均使用文字加图标的共享状态组件、相对时间和注意状态焦点，并以请求 ID 防止账号变化或并发刷新后的旧结果回写；这些焦点与并发行为仍需模拟器/XCTest 实际执行。

比赛中心增量测试源码覆盖：权威快照初始化、插入/更正/tombstone、比分和比赛状态随同更新、确定性排序、旧批次幂等忽略、同批删除后复活拒绝、跨比赛与 revision 冲突拒绝、虚构故障回退快照禁止接入真实增量，以及 LIVE/中场/赛前/终态轮询频率和 30 秒退避上限。Remote provider 测试断言排他 `afterRevision`、无 Bearer、`Cache-Control: no-store`、公共缓存零写入、最新 fixture 映射、删除 mutation、乱序响应拒绝、危险路径 ID 在联网前拒绝及新鲜度记录；Mock 测试只产生一次明确虚构的 VAR 增量，真实 fallback 路由不生成事件。UI 测试源码新增“完成引导 → 打开重要直播比赛 → 看到已连接状态”旅程。前后台取消/恢复、手动快照修复、VoiceOver 重要事件公告及 5 秒运行时轮询仍需 iPhone 模拟器/真机执行。

比赛上下文测试源码覆盖：服务端显式比赛赛季、空积分榜/空交锋、赛事错配、排名倒序、重复球队、场次算术不一致、缺失当前球队、跨赛事 H2H 与主客互换允许，以及错误球队、当前比赛、未完赛、重复、乱序、超限历史拒绝。Remote provider 测试断言两个独立 URL、`limit=10`、`Cache-Control: no-cache`、资源级新鲜度与危险路径 ID 联网前拒绝；Mock 和 fallback 测试断言虚构跨赛事历史及每个资源的 `demoFallback` 标识。UI 测试源码能定位六个比赛中心标签，并进入积分榜和历史交锋已加载状态；大字号卡片布局、RTL 横向表格、错误焦点和 VoiceOver 记录朗读仍需模拟器/真机执行。

阵容/阵型与统计契约测试源码覆盖：完整 `4-3-3`、Mock 的 `4-3-3`/`4-2-3-1`、部分/空名单、阵型与站位不一致时仅禁用球场图、旧载荷缺少 `isStarter` 时默认首发、重复 ID/号码/站位、替补带场上站位、越界站位、非法号码、超过 11 名首发和非法阵型拒绝。统计覆盖空数组、供应商乱序后的固定语义排序、重复 ID/类型、非有限值、错误单位、控球总和错误、计数小数和射正大于射门拒绝。Mock 测试还约束赛前比赛不得获得虚构的比赛内事件或统计。UI 测试源码进入阵容与统计标签并定位语义名单行和控球统计；球场图在辅助功能字号下隐藏、名单改为纵向，统计大字号显示带球队名的值。冻结规则见 `MATCH-LINEUP-STATS-CONTRACT.md`；实际绘制、RTL、VoiceOver 与 XCTest 仍需 macOS/Xcode。

分享与深链测试源码覆盖六类公开实体的 HTTPS/自定义 scheme 往返、Unicode ID、目标 Tab、最新有效链接覆盖与单次消费；边界用例拒绝 HTTP、错误主机、凭证、非默认端口、查询、片段、未知/缺失/多余/重复/尾随路径、基路径混淆、遍历、编码斜杠、双重编码、空白、控制字符和超长 ID。UI 测试源码在引导前注入比赛链接，断言引导未被绕过，完成后打开 Matches Tab 的比赛中心并出现 44pt 原生分享入口。上述源码已通过 AST 和静态契约检查，但系统分享表、Swift 类型检查、XCTest、Universal Links/AASA 和 VoiceOver 仍需 macOS/真机验证。

播放会话测试源码断言 POST、`Content-Type`、`Cache-Control: no-store`、`Idempotency-Key`、设备 ID 和显式 `supportsFairPlay=false`；并覆盖非 HTTPS HLS、过期响应、意外 DRM 响应和网络故障不得回退 Mock。`AppModelTests` 覆盖随机播放设备 ID 的持久稳定性与当前 FairPlay 能力声明。

文章收藏与 Following 测试源码覆盖：游客文章元数据/收藏时间跨存储实例离线持久化、未收藏文章不落盘、更正只刷新已收藏快照、重复收藏/移除幂等、同时间按 ID 稳定排序、v1 文件携带既有进度/视频收藏/关注无损迁移，以及撤稿详情不被快照复活但旧收藏仍可移除。Remote 测试覆盖账户列表/状态/保存/删除的 Bearer、`no-store`、幂等键、公共缓存零写入、无会话发网前拒绝和回显 ID/状态校验；认证测试覆盖游客/账户读写隔离、文章收藏独立 500 项分批、危险/重复/未来记录发网前拒绝、完整计数确认后清理和失败时全量保留。UI 旅程源码从 Explore 收藏文章，在 Following 同时定位文章与原关注对象，再移除文章并确认关注仍保留；Following 的通知、文章、视频和关注区采用独立成功/失败状态。以上源码已通过 Windows 静态检查与 Swift AST，尚未由 XCTest、模拟器、RTL、Dynamic Type 或 VoiceOver 真机执行。

多实体关注测试源码覆盖：同一原始 ID 的球队/球员复合身份隔离、赛事关注、创建时间倒序与类型/ID tie-breaker、失败操作精确回滚、账号切换失败时不暴露旧身份状态、账户 ID 绑定令牌不匹配时发网前拒绝、三类展示快照的 Mock/文件持久化/Remote 解码、重复保存刷新快照但保留原关注时间、无快照旧记录可移除，以及外层目标和内层快照不匹配时整批拒绝。客户端还以具体操作 UUID 阻止退出再登录后的旧操作结果提交。Remote 创建请求只发送类型和 ID，账户响应必须返回服务端权威快照；UI 旅程源码从三类详情入口关注，在混合 Following 列表移除球员并保留球队和赛事。以上仍是源码/AST 证据，未在 XCTest、模拟器、RTL、Dynamic Type 或 VoiceOver 中实际执行。

观看进度/收藏/历史测试源码覆盖：无 Bearer 时在发起网络前拒绝、所有账户请求附带 Bearer 与 `no-store`、写入/单条删除/清空使用幂等键、404 进度映射为空、历史包含已完成项目并按活动时间倒序、零进度与乱序响应被拒绝、单条删除与清空均保留收藏和关注、单条删除按当前游客或账户身份路由、Remote 个人状态不进入公共缓存、Mock 状态往返，以及游客状态跨文件存储实例持久化并在目录数据离线时仍可读取。UI 测试源码使用隔离种子覆盖两条历史中具名确认删除一条并保留另一条；删除按钮同时提供非手势入口、失败重试和无障碍焦点恢复。播放器的 10 秒周期保存、断点 seek、完成标记与关闭冲刷目前仅通过源码/AST 审查，尚未在 AVPlayer 运行时验证。

账户测试源码覆盖：Apple 凭证交换携带 nonce 且不缓存、刷新令牌轮换、登出撤销、Bearer/no-store/幂等头、账户态首页不进入公共缓存也不回退 Mock、账户关注列表/创建/取消与访客路由、最多 500 项的有界进度/视频收藏/文章收藏/关注分批、游客合并载荷不包含视频元数据、HLS URL、文章正文或文章媒体且只携带个人状态 ID/时间、Keychain 会话协调器的并发单飞刷新、显式新登录在刷新竞态中保持最后写入、过期访问令牌恢复、服务器离线时仍完成本机登出，以及只有服务器逐批完整确认后才清除游客状态。永久删号测试源码断言无请求体的 `DELETE /v1/me` 携带 Bearer、`no-store` 与可复用幂等键；服务端失败保留会话和本机数据，204 成功才清除会话与全部游客状态，Keychain 物理清除失败时认证 UI 和数据路由仍立即转为游客。UI 测试源码还断言默认 Mock 构建诚实显示游客模式，且不暴露不可用的 Apple 登录或账户删除按钮。这些测试尚未在 XCTest 中执行。

隐私与设备数据测试源码覆盖：清除本机游客数据不会调用合并、退出或删号服务，不会改变已登录会话；清除失败时保留存储内容、摘要和旧版关注快照以供重试；仅存在未关联视频快照时仍会显示为可清除数据；成功后删除历史、文章/视频收藏、关注、快照和旧版游客关注持久值，但保留语言、引导状态和设备标识。身份回归测试断言登录时清除游客数据仍保留当前账号关注，退出后不会把账号内存关注回灌到游客档案。UI 测试源码覆盖 English Mock 游客从 Profile 进入隐私页、确认清除、看到完成/空状态且破坏性按钮消失；Arabic/English 文案键集合已静态对齐，但 Arabic RTL 旅程尚待模拟器执行。上述测试仅通过源码与 AST 检查，尚未由 XCTest 或 VoiceOver 真机执行。

公共缓存测试源码覆盖：磁盘条目数、实际文件大小、最近写入时间、损坏文件仍可见可清、专用目录外文件保留、50 MiB/200 项策略与按最旧项淘汰；AppModel 测试断言清缓存不改变游客收藏、登录会话、语言、引导状态、通知/播放设备标识，首次存储失败会保留摘要并可重试成功。UI 测试使用仅限 Debug 的隔离缓存种子，覆盖盘点、确认、清除、完成/空状态以及游客数据仍为空的边界。账户私有响应不进入公共缓存由既有 Remote provider 测试继续约束。上述测试仍待 macOS/XCTest 实际执行。

通知测试源码覆盖：未决定权限状态下刷新不会弹出系统授权、拒绝权限不会注册 APNs、授权状态会加载账户偏好并请求 APNs 注册、二进制令牌按小写十六进制上传、访客路由在网络前失败关闭、偏好 PATCH 与设备 PUT 均携带 Bearer、`no-store` 和幂等键，以及格式错误的 locale 在网络前被拒绝。`MATCH-NOTIFICATION-PREFERENCES-CONTRACT.md` 进一步冻结九类账户偏好；测试覆盖旧 `card` 向黄/红牌迁移、换人默认关闭、粒度字段优先、单字段 mutation/PATCH 以及远端换人偏好回显。UI 测试源码断言默认访客构建只显示账户边界且不暴露通知启用按钮。当前 Windows 静态闸门通过 179 个必需文件、885 个双语键和 108 个 App/Widget Swift 文件；ast-grep 0.45.0 解析全部 155 个 Swift 文件为 0 个错误节点，Redocly 2.12.0 以退出码 0 验证 OpenAPI，仍只有既有 12 条 4xx 风格警告。真实 APNs 回调、系统设置往返、事件去重/限流和收件仍需真机与后端执行。

`MockSportsDataProviderTests` 覆盖正文更正版本、七条视频元数据中的五种内容类型、Football/Basketball/Esports 发现分类、显式精选/Trending、权利状态、Arabic 搜索正规化和球队/球员/赛季深度实体场景，并断言演示数据不能生成播放授权。UI 测试源码包含“完成引导 → 探索 → 精选/Trending/Esports/Live/Highlights → 视频详情”和“完成引导 → 探索 → 球队详情”的旅程；视频旅程同时断言不可播放 Mock 不出现播放按钮。

全局转会中心测试源码覆盖：四种筛选映射、首/后页稳定拼接、重复 ID、状态错配、缺失/同一球队路径、日期倒序与 ID tie-break、超页、空/矛盾/循环/不安全游标，以及跨页重复拒绝。Remote 测试断言 `/transfers`、`cursor=page-2`、`limit=30`、`status=COMPLETED`、ETag 新鲜度和坏输入联网前拒绝，并证明状态错配或乱序在缓存写入前失败；Fallback 测试证明恢复性首屏故障显示 `demoFallback` 且移除演示游标，同时后续页故障保持失败、不追加 Mock。UI 旅程源码覆盖 Explore 入口、证据边界、All 首条、Rumored 精确筛选和原 player ID 导航；辅助功能字号把筛选、卡片头和球队轨迹改为纵向。以上已通过静态合同与 Swift AST，XCTest、真实布局、RTL 和 VoiceOver 仍待 macOS/Xcode。

赛季重要日期测试源码覆盖：即将发生与类型筛选的 Provider 顺序保持、进行中跨日区间、月份分组、无效窗口、重复/乱序 ID、缺失详情配对、OpenAPI 必需可空键缺失、文本上限/控制字符与超长事件区间。Remote 测试断言精确 `/season-calendar` 路径、无查询参数、ETag 新鲜度、来源和事件映射，并证明窗口外事件或缺键响应在缓存写入前失败；Mock/fallback 测试约束原子、有序、有界快照和明确 `demoFallback` 来源。UI 旅程源码覆盖 Explore 入口、来源边界、虚构抽签事件和原 competition ID 赛事导航；辅助功能字号把范围、类型筛选和事件头改为纵向。代码审查已修复文本无界输入、控制字符、可空字段缺失、筛选类型语义、时间线布局签名、小号文字对比度、首次错误态闪烁、旧请求来源状态回写，以及相邻转会响应的 OpenAPI 缩进问题。以上已通过 Windows 静态契约、Swift AST 与 OpenAPI 校验；Swift 类型检查、XCTest、真实布局、Arabic RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode。

订阅/去广告契约测试源码覆盖：未配置/无效发布设置失败关闭、同订阅组的一月/一年精确商品约束、过期/撤销/升级/未验证交易拒绝、最新有效权益的稳定选择、广告总闸门、动态商品加载、购买和显式恢复。Debug UI 旅程源码从 Profile 打开具名虚构赛季卡、购买月度预览并断言验证权益抑制符合条件的自有广告位；Release 默认产品/法务配置为空且广告关闭。页面以 StoreKit 本地价格为准，明确不授予媒体权利。以上已通过 Windows 静态契约和 147 文件 Swift AST；Swift 类型检查、XCTest、App Store Connect/Sandbox/TestFlight、购买确认表、pending/退款/撤销、Arabic RTL、Dynamic Type 和 VoiceOver 仍待 macOS/Xcode/真机。

比赛内容契约测试源码覆盖：精确 `fixtureId` 回显、Provider 顺序保持、独立的时刻/视频/文章唯一 ID、0...200 可空分钟、每类最多 10 项和逐条播放权保留。Remote 测试断言 `/fixtures/{fixtureId}/content`、ETag/304、资源级新鲜度，以及错配回显在缓存写入前失败；Mock/fallback 测试断言直播/完赛可有原创虚构内容、赛前为空、所有视频不可播放且故障回退明确标为 `demoFallback`。UI 旅程源码从赛事赛程打开直播比赛，定位 `لحظات من المباراة` 时刻并进入仍显示权利限制的视频详情。横向滚动、Arabic RTL、辅助功能字号的纵向重排、VoiceOver 分钟朗读和实际 XCTest 仍待 macOS/iPhone 执行。

由于当前 Windows 环境没有 Swift/Xcode，这些测试只通过了 AST 语法解析，尚未由 XCTest 执行。

### 获授权视频海报增量

视频列表、精选/Trending 卡片和详情页现在接受可选的双语海报对象；对象包含独立 ID、HTTPS URL、精确 MIME、像素尺寸、Arabic/English 替代文本与来源署名，但不授予视频播放权。缺少海报时继续显示 SportsHub 原创占位图，加载失败只在详情页给出本地化状态和至少 44pt 的重试入口。详情图提供本地化替代文本和可见署名，列表图保持装饰性，避免与卡片标题重复朗读。

共享图片管线采用空配置即拒绝的精确主机白名单，拒绝 HTTP、凭据、非默认端口、片段、根路径、通配主机、localhost、IPv4 地址和跳转；请求不使用 Cookie 或凭据存储，并在流式读取时执行 8 MiB 上限、HTTP 200、精确 MIME、源图尺寸和降采样检查。个人状态仓库在写入内存前先移除 `poster`，`SportsVideo` 编码再显式省略该字段，因此当前进程与磁盘快照都不保留签名 URL 或媒体元数据。

新增契约测试源码覆盖合法映射、缺失/`null` 迁移、不安全 URL、错误 MIME、像素/宽高比/文本边界、编码及内存中的个人快照都不含海报 URL，以及复用解码器的降采样；Remote 测试证明不安全海报在公共缓存写入前被拒绝，Mock 保持海报为空，UI 旅程确认默认视频详情不会虚构失败状态。Windows 静态闸门通过：182 个必需文件、888 个双语共享键、412 个本地化初始化键和 109 个 App/Widget Swift 文件；本轮 13 个改动 Swift 文件由 tree-sitter 解析为 0 个错误节点。全仓扫描另在未改动的 StoreKit 客户端中报告 2 个 tree-sitter `missing` 节点，因此不宣称全仓 AST 为零错误。OpenAPI 3.1 经缓存的 Redocly 2.46.0 验证有效，仍只有既有 12 条逐操作 4xx 风格警告；PyYAML 确认 53 条路径、67 个操作和 140 个 schema。

Swift 类型检查、XCTest、ImageIO/UIKit 实际解码、Arabic RTL、Dynamic Type、VoiceOver、真实 CDN 白名单、内容授权台账及签名 URL 生命周期仍待 macOS/Xcode、真机和授权后端验证。

### 颜色对比抽查

按 WCAG 相对亮度公式计算：

| 颜色 | 对白色背景 | 对黑色背景 | 当前用途 |
|---|---:|---:|---|
| Accent | 5.53:1 | 3.80:1 | 白底强调文字、白字主按钮 |
| Warm | 4.75:1 | 4.42:1 | 状态/图标 |
| Live | 4.94:1 | 4.25:1 | 直播文字与状态 |
| Ink | 17.32:1 | 1.21:1 | 白字深色表面 |

## 尚未证明

以下必须在 macOS + Xcode 环境重新验证，当前不得宣称完成：

1. Swift 类型检查与完整编译。
2. XcodeGen 生成的工程、scheme 和 extension embed 设置。
3. iPhone 模拟器中的 Arabic RTL、English LTR 和动态字体渲染。
4. 单元测试与 UI 测试真实执行。
5. VoiceOver 焦点顺序和朗读质量。
6. Widget、Dynamic Island、Live Activity、签名和真机生命周期。
7. APNs、真实体育数据供应商、远程缓存运行行为、Sign in with Apple/Keychain/令牌轮换/游客合并的真实后端流程、App Store Connect/StoreKit Sandbox/TestFlight 与服务端订阅对账、获授权 HLS 测试流、FairPlay 内容密钥处理和 App Store 发布。
8. 系统分享表、`sportshub://` 启动回调、受控域名的 AASA/Associated Domains、网页/App Store 回退和真实 Universal Links。
