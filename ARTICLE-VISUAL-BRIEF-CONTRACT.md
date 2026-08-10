# Article Visual Brief Contract

## 目的与证据边界

Koora Break 的公开 App Store 描述明确列出信息图（infographics），但公开页面没有证明其私有 CMS schema、素材授权来源、动画能力或统计供应商。因此 SportsHub 实现的是原创的结构化双语视觉报道，不复制页面、品牌或受保护图像，也不把普通封面图冒充信息图。

本切片只证明客户端模型、静态 UI、Mock 演示数据和 API 契约已经实现。真实编辑后台、真实比赛数据、图片版权链、Xcode 渲染和 VoiceOver 运行结果仍未验证。

## 格式与兼容

- `Article.format` 只有 `story` 和 `visualBrief`。
- API 使用 `STORY` 和 `VISUAL_BRIEF`；新响应必须提供 `format`。
- 为滚动部署和既有游客收藏兼容，客户端把缺失 `format` 解码为 `story`。
- 列表只携带格式，不携带完整 Visual Brief；详情响应才携带结构化数据。
- `VISUAL_BRIEF` 必须有非空 `visualBrief`；`STORY` 必须没有 Visual Brief。任何错配都在写入公共缓存前拒绝。

## 结构化内容

一个 Visual Brief 包含：

- 一个双语标题；
- 一个必须可见的双语数据说明；
- 1...4 个按 Provider 顺序展示的区块；
- 每个区块包含唯一 ID、双语标题、类型和有序项目。

区块类型：

- `METRIC_GRID`：2...6 个指标；
- `COMPARISON`：恰好 2 个对比对象；
- `SEQUENCE`：2...6 个按 Provider 顺序排列的步骤或时点。

每个项目包含全篇唯一 ID、双语数值、双语标签和可选的成对双语说明。客户端不计算、不补齐、不重排、不从正文抽取数字，也不把两个来源的数据拼成一个 Visual Brief。

## 输入限制

| 字段 | 最大 Unicode code point 数 |
|---|---:|
| 数值 | 32 |
| 标签 | 80 |
| Visual Brief / 区块标题 | 100 |
| 项目说明 | 160 |
| 数据说明 | 200 |

所有必填文本去除首尾空白后必须非空，且不得含控制字符。ID 为 1...128 字符并拒绝 `/`、`\`、`?`、`#` 和控制字符。载荷不接受任意 HTML、SVG、脚本、URL、远程图片或媒体权限字段。

## 展示与无障碍

- 新闻卡用文字、图标和暖金胶囊共同标明“Visual brief”，不只靠颜色。
- 详情页使用原创数据条与球场符号封面；结构化内容仍全部以原生文本渲染。
- 标题具有 header trait；区块和项目提供稳定辅助功能标识。
- 指标数值使用等宽数字，但不牺牲 Dynamic Type；辅助功能字号把网格和对比布局切为单列。
- RTL 依赖 SwiftUI 的 leading/trailing 语义，不硬编码左右方向。
- 视觉装饰从 VoiceOver 隐藏，数值、标签和说明作为一组朗读；数据说明始终可见。
- Visual Brief 没有仅靠手势触发的动作，也没有低于 44pt 的交互控件。

## Mock 与生产边界

`article-2` 展示五个原创的虚构指标，数据说明明确写明“不是一场真实比赛”。生产接入必须由获授权 Provider 或编辑后台提供完整双语、来源可追溯且已校验的结构化数据；客户端不得把 Mock 数字、第三方截图或未经授权的统计带入生产。

## 验证合同

- 单元测试覆盖旧收藏迁移、合法顺序、格式/载荷错配、区块上限、对比数量、跨区项目 ID 重复、长度和控制字符。
- Remote 测试覆盖完整映射，以及无 Visual Brief 的 `VISUAL_BRIEF` 响应在缓存写入前失败。
- UI 测试源码从首页 Statistics 分类进入 `article-2`，定位 Visual Brief、区块和首项。
- Windows 静态验证不能替代 macOS 的 Swift 类型检查、XCTest、RTL、Dynamic Type、VoiceOver 和真实设备视觉验收。
