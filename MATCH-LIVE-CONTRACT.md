# SportsHub 比赛中心增量更新契约

> 冻结日期：2026-08-05  
> 当前实现级别：HTTP 增量轮询；真实 SSE 与供应商适配延后到获得沙盒后端后。

## 产品边界

- `GET /v1/fixtures/{fixtureId}` 是权威完整快照，包含比分、比赛状态、事件、阵容、统计、来源、更新时间，以及 `FixtureSummary.revision`。
- `GET /v1/fixtures/{fixtureId}/events?afterRevision=N` 是屏幕打开期间的轻量增量通道；它返回事件 upsert/tombstone、最新 `FixtureSummary`、当前修订号和服务端更新时间。
- 增量响应不写入公共磁盘缓存，不携带账户凭据，不生成第二份 `URLCache`，也不在网络失败时切换到 Mock。若完整快照本身来自故障后的虚构 Mock 回退，增量通道必须停下，直到重试先取得真实完整快照，避免真实事件与虚构阵容/统计混合。重新进入前台和手动刷新都先取完整快照修复缺口。
- `/stream` SSE 保留在服务端契约中，但在获得真实流、心跳、重连和代理超时证据前，客户端不会宣称已经接入实时流。

## 修订与顺序

1. `revision` 是单场比赛范围内的全局、单调递增变更序号，不是客户端时间戳。
2. 完整快照的 `fixture.revision` 表示快照已经包含的最高变更序号。
3. 增量请求的 `afterRevision` 是排他游标；响应中的每条 mutation 必须满足 `revision > afterRevision`，并按 revision 严格递增。
4. `fixtureRevision` 必须等于响应中 `fixture.revision`，不得小于请求游标；mutation revision 不得大于它。
5. 同一事件的更正沿用稳定 `id` 并提高 revision；撤回沿用同一 `id`、提高 revision、设置 `isDeleted=true`。
6. 非空事件 `teamId` 必须属于该场比赛的主队或客队；无法归属的事件不进入时间线。
7. 客户端忽略整个旧批次和已经见过的旧 mutation；同一批次可安全重放。缺失、倒序、冲突或跨比赛数据属于契约错误，不作为弱网回退处理。

## 生命周期与节流

- LIVE：约每 5 秒检查一次。
- HALF_TIME：约每 10 秒检查一次。
- UPCOMING：开赛一小时内约每 15 秒检查；更早的比赛约每 60 秒检查。
- FINISHED、POSTPONED、CANCELLED：停止轮询。
- 可恢复错误使用 2、5、10、20、30 秒上限退避；解码、契约、404 和权限错误停止自动重试并提供手动重试。
- App 进入 inactive/background 时立即取消请求并显示暂停状态；回到 active 时重新获取完整快照，再恢复增量通道。

## 界面与辅助功能

- 比赛中心显示连接中、等待开赛、已连接、重试、后台暂停、已结束或不可用状态；图标和文字共同表达，不能只依赖颜色。
- 自动重试不阻塞用户阅读现有快照；不可恢复错误提供至少 44pt 的显式重试按钮。
- 进球、红牌、半场、全场以及事件更正/撤回使用系统辅助功能公告；普通心跳和无变化轮询不抢占 VoiceOver 焦点。
- 时间线以 `minute + addedTime + revision + id` 确定性排序，补时显示为 `45+2′`；更正原位替换，撤回移除。

## 本切片验收

- reducer 测试覆盖新增、更正、撤回、乱序旧批次、快照恢复和确定性排序。
- Remote provider 测试覆盖 afterRevision、`Cache-Control: no-store`、最新比分映射以及错误批次拒绝。
- Mock 只生成明确的虚构增量，不为真实 Remote/Remote-with-fallback 比赛制造事件。
- 页面在前后台切换、手动刷新和并发返回时保持最后修订胜出；动态更新具备可见状态和 VoiceOver 公告入口。
