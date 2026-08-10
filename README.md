# SportsHub iOS

SportsHub 是一个 Arabic-first、English-ready 的原生 iPhone 体育应用工程。当前第一个纵向切片默认使用虚构球队和本地模拟数据，覆盖：

- 首次语言与球队/球员/赛事分区选择、显式跳过和 Profile 后续编辑；三个公共目录独立加载与重试，已有关注不会因重新进入引导而清空
- 首页兴趣直达、仅基于关注球队/赛事 ID 的可解释相关比赛、覆盖全部领域状态的统一比赛筛选、公共重要赛程回退，以及带“全部/已收藏”和真实载荷分类筛选的最新新闻层级
- 五日日期与任意日期日历、当前筛选作用域内的比赛搜索、直播状态与数据驱动赛事筛选、按赛事分组及赛事详情入口
- 比赛中心：摘要、地区化频道/解说指南、事件、阵容、统计、比赛所属赛季积分榜、跨赛事历史交锋、由服务端显式关联的比赛时刻/赛后报道，以及按 revision 合并的比分/事件增量更新
- 关注对象，以及仅账户可用的逐事件通知偏好、显式系统权限请求和 APNs 设备注册界面
- 新闻列表、按 ID 加载正文、更正标记、撤回保护、文章收藏、卡片级公开反应/已发布评论快照、经上游确认权利的可空双语主图，以及带严格双语数据契约的原创 Visual Brief；文章详情另有审核后公开的反应/评论、举报与屏蔽界面，生产写入默认锁定
- 服务端权威的视频精选主视觉、Trending 名次、运动分类和资料库类型频道（全部、直播、回放、集锦、原创、采访），经上游确认展示权利的可空双语海报，以及视频详情与地区/权益限制说明
- Explore 可直达的原创节目库：按运动重新请求完整节目目录，进入 Provider 明确关联的有序分集；视频详情中的节目关系可反向导航，节目归属不推断播放权、主持人、季数或排播
- 短时播放会话、原生 AVKit/HLS 播放器、系统字幕/音轨与画中画入口
- 游客文章/视频收藏、观看进度、完整观看历史、断点恢复、“继续观看”和球队/球员/赛事关注；状态使用 iOS 文件保护持久化并可离线读取
- Following 聚合通知设置、已存文章、已存视频和球队/球员/赛事关注；关注按复合类型+ID 隔离并跨类型稳定排序，各区独立加载，单区失败不会遮挡其他成功内容
- Following 的关注球队赛程看板一次批量加载每队上一场和下一场；失败时仍保留球队入口与取消关注，绝不逐队产生 N+1 请求
- 球队、球员、赛事详情和比赛中心均提供情境化提醒入口：复用同一组全局事件偏好，明确解释当前关注为何使对象/比赛具备提醒资格；关注动作本身不会请求系统权限或承诺推送送达
- “隐私与设备数据”控制中心：盘点并清除本机游客历史、文章/视频收藏、关注及视频快照，提供具名确认、失败保留/重试和账号边界说明
- 登录账户的文章/视频收藏、观看历史与关注同步、带确认的单条历史删除与全部清空，以及 Sign in with Apple、Keychain 会话、单飞刷新令牌、确认式游客状态合并和 App 内永久删号流程
- 对文章、视频、球队、球员和赛事的防抖全局搜索
- 球队与球员详情、赛季阵容、球员转会记录，以及发现页可直达的全局转会中心和赛季重要日期
- 球队频道的上一场/下一场快照，以及由服务端显式关联的近期新闻和相关视频；各内容区独立加载，绝不靠标题猜关联
- 比赛、文章、视频、球队、球员和赛事的原生分享，以及安装后深链导航
- 赛事历史赛季档案，以及按所选赛季隔离的积分榜 / 进球助攻红黄牌榜 / 完整赛季赛程三个按需加载标签；赛程按直播、未开赛、赛果、延期或取消分区并可进入比赛中心
- 首页免费非博彩小组排名预测：保留服务端分组/球队顺序，使用 44pt 上下移动按钮完成完整排序；登录账户以 `no-store` 私有接口读取和保存，截止时间与状态由服务端最终裁决，演示数据绝不冒充个人提交
- Arabic RTL / English LTR
- 由关注球队/赛事真实快照驱动的下一场比赛 Widget，以及比赛中心内用户主动开启、去重更新和终场结束的本地 Live Activity；演示与过期状态均显式标注
- Profile 内原创“赛季卡”订阅中心：StoreKit 动态月/年价格、验证后的本机权益、恢复购买和 Apple 系统管理入口；当前广告默认关闭，订阅不授予任何媒体权利
- 可切换的远程 `/v1` 数据层、ETag 缓存和受控离线回退
- 首页、比赛、新闻和视频列表/详情的可见数据状态：在线更新、ETag 已验证、离线快照、账户私有实时、纯演示、故障后的虚构演示回退与刷新失败

完整产品边界见 [PRD-SPORTS-SUPER-APP.md](PRD-SPORTS-SUPER-APP.md)，实施顺序见 [IMPLEMENTATION-ROADMAP.md](IMPLEMENTATION-ROADMAP.md)，Visual Brief 规则见 [ARTICLE-VISUAL-BRIEF-CONTRACT.md](ARTICLE-VISUAL-BRIEF-CONTRACT.md)，文章卡互动快照规则见 [ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md](ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md)，历史赛季规则见 [HISTORICAL-SEASONS-CONTRACT.md](HISTORICAL-SEASONS-CONTRACT.md)，订阅/去广告规则见 [SUBSCRIPTION-AD-FREE-CONTRACT.md](SUBSCRIPTION-AD-FREE-CONTRACT.md)，文章社区规则见 [ARTICLE-COMMUNITY-CONTRACT.md](ARTICLE-COMMUNITY-CONTRACT.md)，转会中心规则见 [TRANSFER-CENTER-CONTRACT.md](TRANSFER-CENTER-CONTRACT.md)，赛季重要日期规则见 [SEASON-CALENDAR-CONTRACT.md](SEASON-CALENDAR-CONTRACT.md)，Widget/Live Activity 规则见 [WIDGET-LIVE-ACTIVITY-CONTRACT.md](WIDGET-LIVE-ACTIVITY-CONTRACT.md)，地区化播出指南规则见 [BROADCAST-GUIDE-CONTRACT.md](BROADCAST-GUIDE-CONTRACT.md)，免费预测冻结规则见 [PREDICTION-GAMES-CONTRACT.md](PREDICTION-GAMES-CONTRACT.md)，文章收藏冻结规则见 [ARTICLE-FAVORITES-CONTRACT.md](ARTICLE-FAVORITES-CONTRACT.md)，多实体关注规则见 [MULTI-ENTITY-FOLLOWS-CONTRACT.md](MULTI-ENTITY-FOLLOWS-CONTRACT.md)，关注球队赛程看板规则见 [FOLLOWING-TEAM-DASHBOARD-CONTRACT.md](FOLLOWING-TEAM-DASHBOARD-CONTRACT.md)，情境化提醒入口规则见 [CONTEXTUAL-ALERTS-CONTRACT.md](CONTEXTUAL-ALERTS-CONTRACT.md)，赛事赛程规则见 [COMPETITION-FIXTURES-CONTRACT.md](COMPETITION-FIXTURES-CONTRACT.md)，比赛内容规则见 [FIXTURE-CONTENT-CONTRACT.md](FIXTURE-CONTENT-CONTRACT.md)，视频发现规则见 [VIDEO-DISCOVERY-CONTRACT.md](VIDEO-DISCOVERY-CONTRACT.md)，视频详情编辑上下文规则见 [VIDEO-DETAIL-EDITORIAL-CONTRACT.md](VIDEO-DETAIL-EDITORIAL-CONTRACT.md)，球队上下文规则见 [TEAM-CONTEXT-CONTRACT.md](TEAM-CONTEXT-CONTRACT.md)，多兴趣首启规则见 [MULTI-INTEREST-ONBOARDING-CONTRACT.md](MULTI-INTEREST-ONBOARDING-CONTRACT.md)，首页聚合规则见 [EXPLAINABLE-HOME-CONTRACT.md](EXPLAINABLE-HOME-CONTRACT.md)，首页新闻发现规则见 [HOME-NEWS-DISCOVERY-CONTRACT.md](HOME-NEWS-DISCOVERY-CONTRACT.md)，首页比赛筛选规则见 [HOME-MATCH-FILTER-CONTRACT.md](HOME-MATCH-FILTER-CONTRACT.md)，比赛发现规则见 [MATCHES-DISCOVERY-CONTRACT.md](MATCHES-DISCOVERY-CONTRACT.md)，任意日期与比赛搜索规则见 [MATCHES-DATE-SEARCH-CONTRACT.md](MATCHES-DATE-SEARCH-CONTRACT.md)，服务契约见 [api/openapi.yaml](api/openapi.yaml)。

文章授权主图的权利、URL、尺寸、缓存、失败占位和无障碍规则单独冻结在 [ARTICLE-HERO-MEDIA-CONTRACT.md](ARTICLE-HERO-MEDIA-CONTRACT.md)。

视频海报与播放权严格分离，其权利、URL、缓存、原创布局和无障碍规则冻结在 [VIDEO-POSTER-MEDIA-CONTRACT.md](VIDEO-POSTER-MEDIA-CONTRACT.md)。

节目目录、运动筛选、分集关系、分页回退与内容权利边界冻结在 [VIDEO-PROGRAM-HUB-CONTRACT.md](VIDEO-PROGRAM-HUB-CONTRACT.md)。

## 数据模式

`project.yml` 目前安全地默认：

```yaml
SPORTS_DATA_MODE: mock
SPORTS_API_BASE_URL: https://api.example.invalid/v1
SPORTS_AUTH_ENABLED: false
SPORTS_PUBLIC_WEB_BASE_URL: ""
SPORTS_MEDIA_ALLOWED_HOSTS: ""
SPORTS_APP_GROUP_ID: group.com.example.sportshub.shared
SPORTS_COMMUNITY_ENABLED: false
SPORTS_COMMUNITY_STANDARDS_URL: ""
SPORTS_COMMUNITY_SUPPORT_URL: ""
SPORTS_PREMIUM_MONTHLY_PRODUCT_ID: ""
SPORTS_PREMIUM_ANNUAL_PRODUCT_ID: ""
SPORTS_PREMIUM_PRIVACY_URL: ""
SPORTS_PREMIUM_TERMS_URL: ""
SPORTS_ADVERTISING_ENABLED: false
```

接入获授权的后端时，将 URL 替换为真实 HTTPS `/v1` 地址，并把模式改为：

- `remote`：错误直接呈现，不用演示数据掩盖问题。
- `remoteWithMockFallback`：仅网络中断、429 或服务端暂时不可用时回退；鉴权、地区限制、解码和契约错误不会回退。全局搜索、播放授权与已登录的个性化首页永远不回退到 Mock，因为这些界面没有足够的逐响应来源或权限边界来安全混入虚构数据。

`SPORTS_MEDIA_ALLOWED_HOSTS` 接受以逗号、分号或空白分隔的精确 CDN 主机名；不接受 URL、通配符、localhost 或 IP。检查入配置保持空值，因此文章主图和视频海报联网默认失败关闭，不能用占位域名冒充真实媒体集成。

远程响应在映射并通过字段验证后才写入缓存；后续请求使用 ETag/`If-None-Match`。文章收到 410 撤回响应时不会使用旧缓存或 Mock 复活；视频可用性由服务端元数据决定。播放 URL 只存在于不缓存、不序列化的短时会话中，并且必须是 HTTPS。当前构建只声明无 DRM HLS 能力；在真正接入 FairPlay 内容密钥委托前不会谎报 DRM 能力或绕过保护。积分榜、榜单、阵容和赛事赛程只使用服务端明确提供的赛季 ID，不由客户端猜测；赛季赛程逐页校验回显范围、全局顺序、唯一 ID 和游标后才提交，后续页失败不会返回半份列表。球队详情另校验球队回显、比赛归属、快照一致性、状态、时间顺序、赛事引用和跨窗口唯一性；相关新闻/视频只来自回显同一 `teamId` 的 `/teams/{teamId}/content`，不会以队名或标题关键词推断。比赛时刻与报道同样只来自精确回显 `fixtureId` 的 `/fixtures/{fixtureId}/content`；它独立于比分和事件轮询，列表顺序由服务端决定，卡片本身不授予播放权。比赛载荷中的播出信息只允许最多 12 条经校验的地区、双语频道、可空双语解说和规范音频语言元数据；它没有 URL、价格或权益字段，不能用来推断订阅或播放授权。

文章社区读取和写入均使用 `no-store`，不会进入公共 ETag 缓存，也不会在故障时回退到虚构 Mock。反应、评论、举报和屏蔽只在真实登录可用，账号切换会作废旧身份请求；评论提交以后端审核状态为准，不做乐观公开。仓库默认只展示具名虚构评论，UI 与会话数据路由会共同锁定写入；只有审核过滤、举报、屏蔽、封禁/申诉流程、公开社区规范和发布方支持入口均已就绪，并正确配置 `SPORTS_COMMUNITY_ENABLED`、`SPORTS_COMMUNITY_STANDARDS_URL` 与 `SPORTS_COMMUNITY_SUPPORT_URL` 后，才可开启生产功能。

Visual Brief 只使用双语语义文本、数值、标签和可选说明，按指标网格、双项对比或序列展示；没有 HTML、SVG、远程素材或媒体权利字段。格式与详情载荷必须匹配，区块/项目数量、唯一 ID、文字长度和控制字符都在公共缓存写入前验证。旧版游客收藏若没有格式字段会迁移为普通文章。Mock `article-2` 的五个数字完全虚构，并在页面中持续显示“不是一场真实比赛”的数据说明；真实统计和编辑来源仍需授权 Provider/CMS。

文章卡互动摘要只显示服务端随 `ArticleSummary` 下发的公开总反应数和已发布评论数，范围为 0...20 亿。它不包含当前用户反应、屏蔽状态、待审核评论、热度或分享分析；旧缓存或滚动接口缺失字段时直接隐藏，绝不把未知显示为零。卡片快照沿用公共 ETag/离线缓存，详情页社区则继续使用更新的 `no-store` 读取，因此两者可能暂时不同且不会冒充实时。卡片保持单一文章导航目标，分享仍通过详情页原生系统分享完成；分享次数等待正式分析/去重契约，不从截图或本机点击虚构。完整规则见 [ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md](ARTICLE-ENGAGEMENT-SUMMARY-CONTRACT.md)。

文章主图只接受 `ArticleSummary.heroMedia` 中的上游权利断言和双语替代文本/可见署名；客户端不会把任意网页图片称为已授权。DTO 在公共缓存写入前校验 HTTPS 直链、MIME、尺寸、像素数、比例和文字边界，加载器再使用精确主机 allowlist、无 Cookie/无 Bearer 会话、拒绝重定向、8 MiB 流式上限与解码前像素核对。缺失资源沿用原创 SportsHub 封面且不宣告为错误；详情失败才显示状态和 44pt 重试。Mock 不含第三方照片，个人收藏快照不保存媒体 URL。完整规则见 [ARTICLE-HERO-MEDIA-CONTRACT.md](ARTICLE-HERO-MEDIA-CONTRACT.md)。

视频 `poster` 使用同一套公开图片安全管线，但与 `isPlayable`、播放会话、精选/Trending 顺序、收藏和进度完全独立。列表、精选、Trending 和详情可显示经上游确认展示权利的海报；卡片图对 VoiceOver 为装饰，详情显示双语替代文本、署名和失败重试。个人视频快照主动省略海报及签名 URL，Mock 继续只用原创渐变/SF Symbol，不含参考 App 图片。完整规则见 [VIDEO-POSTER-MEDIA-CONTRACT.md](VIDEO-POSTER-MEDIA-CONTRACT.md)。

节目中心只消费 `/video-programs` 与 `/video-programs/{programId}` 的显式关系。目录运动筛选是新的服务端请求，不用当前不完整页做本地全量筛选；节目与分集均保留 Provider 顺序和游标，首屏可整份切换到具名虚构 Mock，后续页失败只重试而不混入 Mock。节目对象没有 Logo、主持人、赞助、排播、季数或商标字段，分集继续逐条保留视频权利状态。完整规则见 [VIDEO-PROGRAM-HUB-CONTRACT.md](VIDEO-PROGRAM-HUB-CONTRACT.md)。

游客的文章/视频收藏、观看进度、观看历史和关注独立保存在 Application Support，不会写入公共 HTTP 缓存；Remote/Mock 目录数据切换不会抹掉这些状态。关注以 `(type, entityId)` 作为身份，保存球队、球员或赛事的最小展示快照；旧版无快照球队记录仍可显示为不可用项并移除，绝不会靠逐项网络查询隐藏加载失败。账户关注请求的令牌按预期账户 ID 解析，身份或具体操作 UUID 过期的响应不会提交，避免退出再登录竞态覆盖当前状态。文章收藏只保存列表所需元数据、ID 与收藏时间，不保存正文、媒体 URL、账户 ID 或令牌；未收藏阅读不形成持久快照，更正只更新仍在收藏的元数据并保留原收藏时间。历史页同时显示未完成和已完成视频；单条删除和“清空历史”都只删除观看位置与完成记录，保留文章/视频收藏和关注。单条删除提供明确的 44pt 操作、视频具名确认、失败重试与 VoiceOver 焦点恢复；请求完成期间若账号身份变化，旧身份列表会被丢弃并按新身份重载。账户切片现已实现原生 Sign in with Apple、SHA-256 nonce、Keychain 会话、旋转刷新令牌的单飞协调、Bearer `no-store` 请求、账户文章收藏与关注同步、显式游客合并和 Profile 内永久删号。合并只发送视频 ID、进度、完成状态、文章 ID、关注对象类型/ID 和各自更新时间，不发送关注展示快照、视频元数据、播放 URL、文章正文或文章媒体；只有每一批都被服务器完整确认后才清除本地游客记录。永久删号使用具名两步确认；服务端 204 契约要求先删除可删除的账户数据、会话和通知设备并撤销 Sign in with Apple 授权，失败时保留当前会话和本地数据；确认完成后客户端清除 Keychain 与本机游客状态，并以本进程抑制和持久失效标记防止清理错误复活旧账号。`SPORTS_AUTH_ENABLED` 默认仍为 `false`，因为占位域名没有真实身份后端；只有替换为获授权 HTTPS `/v1` 服务并配置 Apple Developer 能力后才能设为 `true`，因此当前不能宣称真实账户、跨设备同步或真实删号已经运行验证。

隐私页现在独立统计本机游客观看记录、文章/视频收藏、关注和视频元数据快照；用户确认后才执行本机清除，任何存储错误都会保留原数据并提供重试。清除不会联系服务器、不会退出登录，也不会删除已登录账号、语言、引导状态、设备标识、通知设置或公共内容缓存。旧版游客关注快照只从游客专用的持久值迁移，不能再把账号内存状态回灌为游客关注。当前开发构建没有伪造正式隐私政策链接或发布主体；二者仍是分发前硬闸门。

同一隐私控制中心也会盘点 App 自主管理的公共体育响应缓存，显示实际文件数、磁盘占用、50 MiB 上限和最近更新时间，并提供具名确认、失败保留与重试。该缓存最多保留 200 项，超限时优先淘汰最旧项；默认网络会话禁用额外的 `URLCache`，避免出现界面无法盘点的第二份 HTTP 响应缓存。手动清除只删除专用 `SportsHubAPI` 缓存目录，不触碰游客个性化、Keychain 会话、账号私有 `no-store` 响应、播放会话、语言、通知或设备标识；后续公共请求可能重新生成缓存。

公共首页、赛程/比赛中心、新闻和视频列表/详情现在同时显示数据来源与时间。只有成功解码并通过领域契约的数据才会标记为在线或已重新验证；弱网读取本地响应会明确标成离线快照并显示快照时间，Mock 故障回退会明确写明是虚构演示数据，刷新失败不会冒充离线缓存。已登录的个性化首页单独标为账户实时数据，继续保持 Bearer `no-store`，不会被描述成公共缓存。状态使用文字和图标共同表达；下拉刷新后以及离线/回退/失败等需要注意的变化会把 VoiceOver 焦点移到状态提示。账号变化和并发刷新采用最后一次请求生效，避免旧身份或旧日期结果回写当前页面。

首页新闻区把公开首页载荷与 `favoriteArticles()` 作为两个明确范围：分类只来自当前范围真实出现的 `categoryKey`，并按首次出现顺序展示；“全部分类”保持 Provider 顺序。第一条文章仅使用更醒目的原创卡片建立视觉层级，不声称热门、独家、推荐或编辑精选。收藏请求的加载/空/失败独立于公开首页，账号切换会立即清空旧身份收藏并作废在途请求。辅助功能字号下，范围与分类控件都改为纵向 44pt 原生按钮。

首页比赛区使用一个全局状态筛选同时约束“关注相关”和公共比赛，过滤发生在可解释分区之后，因此不会改变比赛 ID、关注原因、分区或 Provider 顺序。直播包含进行中和中场；即将开始、已结束、延期、取消均精确匹配，只显示当前载荷实际存在的状态项。刷新后若原状态不再存在会回到“全部”；有关注对象但当前筛选没有相关比赛时会显示筛选专用空态，不会误称完全没有相关比赛。辅助功能字号把横向筛选轨切换为纵向 44pt 原生按钮。

专门的比赛页现在提供以今天为中心的五日日期轨、任意日期图形日历、全部/直播状态、全部/关注范围、由所选日期载荷首次出现顺序生成的赛事筛选，以及按赛事分组的比赛卡。关注范围只接受显式关注的主客队或赛事 ID，每张命中卡片和其搜索结果都显示球队、赛事或两者同时命中的文字原因；球员关注不会被猜成参赛关系。身份切换先禁用关注范围、撤销旧同步并回到全部，防止短暂显示旧账户关注；同步失败会保留全部比赛、显示具名重试，绝不会把网络错误冒充成“没有关注”。日历选择以用户当前时区的本地自然日为请求键，并用日历算术跨越 DST；任意日期会重新居中五日轨但保留状态筛选。赛事列表在状态或关注范围切换时保持稳定；分组和组内比赛分别保持首次赛事顺序与 Provider 顺序。选择某赛事后若当前组合没有比赛，会显示作用域专用空态而不是偷偷切换筛选；新日期载荷不再包含原赛事时才归一化为全部赛事。顶部搜索只匹配当前日期及当前状态/范围/赛事筛选后可见比赛的双方队名、缩写、赛事和场馆，支持英文大小写及阿拉伯文变体归一化并保留原 fixture ID，不调用全站搜索或生成额外网络请求。分组标题可直接进入赛事详情。大字号把日期、状态、范围和赛事控件重排为纵向 44pt 按钮，选择不只依赖颜色。由于供应商没有热门度或编辑排序字段，客户端没有虚构 Jdwal 的 Top/热门范围；完整规则见 [MATCHES-FOLLOWING-CONTRACT.md](MATCHES-FOLLOWING-CONTRACT.md)。

赛事详情现把 Provider 明确发布的赛季做成新到旧档案，并把积分榜、榜单和赛程做成三个显式按需加载标签，避免进入页面就并发请求所有内容。赛季目录最多 50 项，客户端在展示前拒绝重复 ID、倒序错误、无效日期和 `currentSeasonId`/`isCurrent` 冲突，不推断缺失赛季或宣称档案完整。赛程接口要求赛事与赛季双重回显，最多聚合 1,000 场，并在缓存写入前校验每页上限、跨页时间/ID 稳定排序、全局去重和非循环游标；任何后续页失败只允许整份回退到明确标识的 Mock 数据。展示层把所有状态完整互斥地分为直播、未开赛、赛果和延期/取消，点击原 fixture ID 进入现有比赛中心。旧标签、旧赛季或旧榜单类别的异步结果不能覆盖当前选择；档案状态使用文字而非只靠颜色，大字号改用纵向全宽 44pt 布局，错误会迁移 VoiceOver 焦点。完整规则见 [HISTORICAL-SEASONS-CONTRACT.md](HISTORICAL-SEASONS-CONTRACT.md) 与 [COMPETITION-FIXTURES-CONTRACT.md](COMPETITION-FIXTURES-CONTRACT.md)。

比赛中心打开期间会用排他的 `afterRevision` 游标获取无缓存增量：事件新增、更正、撤回和比分/状态变化进入同一个单场单调序列，旧批次可重放但不会覆盖新状态，删除后的事件不会被增量复活。前台恢复和手动刷新先取权威完整快照；后台立即暂停；结束、延期或取消后停止轮询。连接、等待、重试、暂停和终止均有双语文字+图标状态，重要事件及时间线纠错预留 VoiceOver 公告。真实比赛增量永不回退到 Mock；当前默认 Mock 只产生明确的虚构 VAR 示例。完整冻结规则见 [MATCH-LIVE-CONTRACT.md](MATCH-LIVE-CONTRACT.md)，真实 SSE 仍需供应商沙盒和比赛日证据后再接入。

下一场比赛 Widget 不再生成固定虚构对阵：App 从最近一次完整接收的首页比赛集合中，只对显式关注球队/赛事命中的直播、半场或待赛比赛确定性选出一场；当前不声称已在后台扫描供应商的全部赛事。最小双语公共快照写入 App Group，并在成功写入或清空后重载 Widget。没有匹配项、共享容器不可用或载荷损坏时均显示具名空态；直播快照 15 分钟未更新、待赛快照超过 24 小时或已越过开球 15 分钟会提示打开 App 刷新。比赛中心的 Live Activity 必须由用户主动开启，只允许直播/半场或四小时内的待赛，以便在 ActivityKit 最长八小时的活动寿命中为比赛和延迟保留另外四小时；Provider 仍标为待赛但已开球超过 15 分钟时拒绝启动。内容变化去重更新，过期状态具名显示，完赛携带最终比分并保留一小时，取消、延期或手动停止立即关闭。当前 `pushType` 明确为 `nil`，本地更新仅在该比赛中心页面处于前台时运行；离开页面后不会伪称仍有远程持续更新。`group.com.example.sportshub.shared` 仍是占位符，必须替换为开发者账户持有的 App Group 并为 App/Widget 重新签名后才能真机验证。完整边界见 [WIDGET-LIVE-ACTIVITY-CONTRACT.md](WIDGET-LIVE-ACTIVITY-CONTRACT.md)。

积分榜与历史交锋使用两个独立的比赛作用域接口和独立页面状态。积分榜响应显式携带该场比赛的赛季，客户端不会拿赛事“当前赛季”猜历史比赛；历史交锋只接受目标两队已经结束且比分完整的比赛，允许跨赛事但每张卡片都标注赛事名称，并只描述当前返回窗口的胜/平/负，不生成预测。常规字号显示密集积分表，辅助功能字号改为纵向卡片；当前两队、最近状态、错误、空结果、来源和更新时间都不只靠颜色表达。完整边界见 [MATCH-CONTEXT-CONTRACT.md](MATCH-CONTEXT-CONTRACT.md)。

阵容页现在区分首发与替补，并只在恰好 11 名首发、单一门将、合法阵型以及完整且不重复的标准化站位全部一致时显示阵型图；不完整名单会保留已发布球员并给出说明，不由客户端猜补。辅助功能字号和 VoiceOver 始终以文字名单为主，阵型图只是隐藏于辅助功能树之外的视觉补充。统计按固定语义顺序展示，拒绝重复类型、错误单位、不成立的控球总和及射正数大于射门数等矛盾；空数据使用与比赛状态对应的明确说明而非空白面板。完整边界见 [MATCH-LINEUP-STATS-CONTRACT.md](MATCH-LINEUP-STATS-CONTRACT.md)。

详情页使用系统 `ShareLink` 分享比赛、文章、视频、球队、球员和赛事。入站路由只接受这六类精确路径，ID 只解码一次并拒绝目录穿越、编码斜杠、双重编码、查询参数、片段和非可信主机；引导流程未完成时只排队，完成后才切换到对应 Tab 并打开详情。仓库中的 `SPORTS_PUBLIC_WEB_BASE_URL` 故意为空，所以当前分享的是本地化文本，`sportshub://` 只用于已安装 App 和确定性 UI 测试，不会作为公开分享链接。上线 HTTPS 分享前必须填入受控域名，并由该域名部署 AASA 和网页/App Store 回退；源码中的路由支持本身不能证明 Universal Links 已部署。完整边界见 [LINK-ROUTING-CONTRACT.md](LINK-ROUTING-CONTRACT.md)。

通知切片的源码不会在启动时弹权限框：只有已登录用户点击启用后才请求系统授权。账户偏好现明确区分突发新闻、阵容、开球、进球、黄牌、红牌、换人、中场和终场九类；旧服务端的 `card` 聚合值只迁移到黄/红牌，缺失的换人值保守关闭，完整规则见 [MATCH-NOTIFICATION-PREFERENCES-CONTRACT.md](MATCH-NOTIFICATION-PREFERENCES-CONTRACT.md)。已获授权时，App 每次回到活动态都会向 APNs 重新注册；Apple 返回的二进制令牌只会转为小写十六进制并通过 Bearer、`no-store`、幂等 HTTPS 请求上传，不用于识别用户，也不写日志。通知偏好和设备绑定不回退到 Mock；登出契约会撤销当前刷新令牌族及其设备绑定。默认 Mock/关闭鉴权构建只诚实显示“需要登录”，因此当前不能宣称真实推送已经可用。

当前没有真实后端或体育内容授权，因此默认 Mock 数据全部不可播放；这不影响对远程获授权 HLS 会话的客户端实现边界，但也不能作为真实视频播放验证。

视频 Explore 使用独立 `/videos/discovery` 快照：每条完整权利过滤元数据带一个服务端 sport，`featuredVideoId` 明确指定主视觉，`trendingVideoIds` 的数组位置就是名次；客户端不会拿播放量、收藏或关注猜热榜，也不会让编辑位置改变播放权。快照最多 100 条、热榜最多 10 条，所有引用、唯一性和精选/热榜互斥都在写入缓存前验证；资料库再按 sport 与现有 `type` 做交集筛选并保持 Provider 顺序。原来的 `/videos` 完整列表仍按 100 条分页聚合至多 1,000 条。默认 Mock 以原创虚构元数据覆盖 Football、Basketball、Esports 和五种内容类型，不含受保护图片或音视频；直播也不会把未知时长显示成 `0:00`。Exclusive、观看数与个性化推荐仍没有被虚构。完整规则见 [VIDEO-DISCOVERY-CONTRACT.md](VIDEO-DISCOVERY-CONTRACT.md)。

Explore 全局搜索现在把五类内容放入同一条可审计链路：2–100 字符、350ms 防抖、最新请求身份校验、结果摘要，以及 All/新闻/视频/球队/球员/赛事范围。All 严格保留服务端相关性顺序，类型范围只取其有序子序列；界面明确写“已加载结果”，不会把首批 100 条冒充全库总数。Mock 的 Arabic 匹配会去除变音和 tatweel、统一 Alef 变体与 Alef Maqsura，再按“精确标题/别名、前缀、标题包含、正文包含”稳定排序，但不做音译、不混同 `ة`/`ه`，也不把这套演示顺序冒充远程算法。远程搜索没有单条来源状态面板，所以弱网失败不会静默返回旧缓存或虚构 Mock 命中，而是进入可重试错误态。完整规则见 [ARABIC-SEARCH-CONTRACT.md](ARABIC-SEARCH-CONTRACT.md)。

视频详情现在把截图中可见的折叠简介、发布日期与既有播放/收藏动作组合为一个原生页面，并由 `/videos/{videoId}` 明确返回出版方、节目和最多 10 条有序相关推荐。响应 ID 必须与路径 ID 相同；相关 ID 唯一、不得自引用，每条内容保留自身播放权限，任何违约都在缓存前拒绝。短简介在大字号下不会因四行限制而永久截断，长简介使用 44pt 的 Show more/Show less 控件。相关推荐不是客户端从标题、收藏或观看历史推断的个性化结果。完整规则见 [VIDEO-DETAIL-EDITORIAL-CONTRACT.md](VIDEO-DETAIL-EDITORIAL-CONTRACT.md)。

球队频道把严格验证后的最近已结束比赛与最近待赛比赛放在两个独立槽位，任一为空都不会挪用直播、延期或其他球队的比赛填充。后续赛程/赛果保留服务端稳定顺序；阵容和内容失败互不遮挡。球队详情与 `/teams/{teamId}/content` 是两个独立 ETag 资源，真实缓存、刷新失败和虚构回退分别标示；文章按发布时间倒序，视频保留服务端编辑顺序且继续展示真实的不可播放原因。Mock 只提供原创的虚构文字和不可播放元数据。完整规则见 [TEAM-CONTEXT-CONTRACT.md](TEAM-CONTEXT-CONTRACT.md)。

赛事和球员详情现在也有独立的近期内容频道。`/competitions/{competitionId}/content` 不依赖赛季，所以即使赛事没有有效赛季，用户仍可进入“最新”；`/players/{playerId}/content` 位于赛季统计与转会记录之间。两类响应都必须精确回显路径 ID、每类最多 10 项、整批校验后缓存，客户端不会用名称、球队、统计、标题或描述猜关联。页面使用青色新闻轨与暖金视频轨，两轨拥有独立空态；视频卡仅是权利过滤后的元数据，不授予播放权。完整规则见 [ENTITY-EDITORIAL-CONTENT-CONTRACT.md](ENTITY-EDITORIAL-CONTENT-CONTRACT.md)。

Explore 顶部现在提供全局转会中心入口。`/transfers` 按 Provider 的最新优先顺序分页，支持全部、已完成、已达成和传闻状态；每张卡都保留显式状态，绝不会把 `RUMORED` 改写为已确认。响应在缓存前检查页大小、唯一 ID、有效球队路径、状态一致性、日期/ID 排序和游标语义，跨页再检查重复与循环。虚构回退仅允许首屏请求，页面会显示来源提示并移除后续游标；真实后续页失败会保持失败，防止把 Mock 与已加载的真实记录混合。辅助功能字号把筛选和球队轨迹改为纵向布局。完整规则见 [TRANSFER-CENTER-CONTRACT.md](TRANSFER-CENTER-CONTRACT.md)。

Explore 顶部也提供赛季重要日期入口。`/season-calendar` 一次返回由 Provider 编排的完整日期窗口、来源、更新时间和最多 200 个事件；支持即将发生/完整赛季范围，以及仅针对当前载荷实际存在类型生成的筛选。客户端校验窗口、唯一 ID、时间顺序、跨日区间、赛事快照和文本边界后才原子缓存，绝不从比赛或转会数据推断日期，也不把真实与 Mock 事件合并。页面以原创纵向赛季脊线分月呈现，带赛事的事件可进入现有赛事详情；辅助功能字号下筛选改为纵向 44pt 控件。提醒、票务和个人日历写入继续延后。完整规则见 [SEASON-CALENDAR-CONTRACT.md](SEASON-CALENDAR-CONTRACT.md)。

Following 的球队赛程看板使用 `/teams/match-snapshots` 批量资源：Provider 最多接收 100 个唯一 ID，网络层每批最多 20 个并保持关注顺序。响应必须逐项回显球队，上一场只能是已结束、下一场只能是待赛，嵌入球队快照必须完全一致；任一批次不完整、乱序或错配都会在缓存前拒绝。加载、错误、重试和新鲜度独立于收藏文章、收藏视频与关注同步；关注变化通过请求 UUID 作废旧结果。辅助功能字号下球队操作和两个比赛槽纵向排列。完整规则见 [FOLLOWING-TEAM-DASHBOARD-CONTRACT.md](FOLLOWING-TEAM-DASHBOARD-CONTRACT.md)。

Profile 的订阅中心只在两项 App Store Connect 自动续订产品（同一订阅组、精确一月/一年周期）和发布方 HTTPS 隐私/条款链接全部有效时开放购买。商品名、说明和价格完全取自 StoreKit；本机只接受配置产品的已验证、未撤销、未升级且未过期交易。恢复购买显式调用 Apple 同步，管理使用系统订阅页。当前 `SPORTS_ADVERTISING_ENABLED` 为 `false`，仓库没有广告 SDK 或广告位；未来若另行通过广告隐私闸门，唯一广告资格规则是“广告开关开启且没有有效订阅”。订阅不会解锁直播、视频、新闻或任何第三方权利。完整规则见 [SUBSCRIPTION-AD-FREE-CONTRACT.md](SUBSCRIPTION-AD-FREE-CONTRACT.md)。

## 工程生成

当前仓库使用 `project.yml` 描述 Xcode 工程，避免在 Windows 上手写易损坏的 `project.pbxproj`。

在安装了当前稳定版 Xcode 的 macOS 上执行：

```bash
brew install xcodegen
xcodegen generate
open SportsHub.xcodeproj
```

打开工程后：

1. 为 `SportsHub` 和 `SportsHubWidgets` 选择开发团队。
2. 将 `com.example.sportshub` 改为自己的唯一 Bundle ID。
3. 在 Apple Developer 中为该 App ID 启用 Sign in with Apple 与 Push Notifications；接好真实账户和通知后端后，再把 `SPORTS_AUTH_ENABLED` 设为 `true`。
4. 如需公开分享链接，把 `SPORTS_PUBLIC_WEB_BASE_URL` 设为自有 HTTPS 基地址，再配置 Associated Domains、部署匹配的 AASA 和网页/App Store 回退；不要使用仓库占位域名。
5. 只有在真实审核后端、举报/屏蔽/封禁/申诉流程和发布方支持均可验收后，才把 `SPORTS_COMMUNITY_ENABLED` 设为 `true`，并为社区规范与支持配置真实 HTTPS URL。
6. 在 App Store Connect 建立同一订阅组内的一月和一年自动续订产品，配置四项 `SPORTS_PREMIUM_*` 设置及正式隐私/条款 URL；在 Sandbox/TestFlight 验证购买、pending、恢复、撤销和管理。广告保持关闭，直至 SDK、同意、App Privacy 和地区/儿童规则单独通过审核。
7. 选择 iPhone 模拟器运行 `SportsHub` scheme。
8. 使用真机验证 Apple 登录、Keychain 恢复、StoreKit、Universal Links、系统分享、APNs、Widget、Dynamic Island 和 Live Activity。

命令行验证示例：

```bash
xcodegen generate
bash scripts/verify-macos.sh

# 使用本机存在的模拟器运行测试
xcodebuild \
  -project SportsHub.xcodeproj \
  -scheme SportsHub \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

模拟器名称必须替换为本机实际存在的设备。

## Windows 静态检查

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-scaffold.ps1
```

这个脚本检查工程结构、本地化键一致性、危险 URL 和参考 App 品牌误用。它不等同于 Swift 编译或 Xcode 测试。

API 契约可用 Redocly 校验：

```bash
npx @redocly/cli lint api/openapi.yaml
```

## 当前验证边界

- 已验证：文件结构、配置引用、本地化键一致性、占位品牌隔离、Swift AST 语法、深链/分享静态边界、APNs entitlement 的 Debug/Release 环境引用和 OpenAPI 结构。
- 尚未验证：Swift 类型检查/编译、单元测试真实执行、Xcode scheme、签名、模拟器渲染、StoreKit Sandbox/TestFlight 购买与恢复、系统分享表、Universal Links/AASA、VoiceOver 焦点、真实账户删除/Apple 令牌撤销、生产内容审核/申诉后台与 UGC 审核证据、Widget、Live Activity 和真机通知。
- 不应提交商店：当前没有正式 App Icon、品牌、已授权真实后端/内容、隐私清单、正式隐私政策 URL/发布主体或发布证书。
