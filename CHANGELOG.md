# CHANGELOG

## Unreleased

### Added
- 新增 `speed --tcp-skyline`，在已有 TCP 调优完成后可选安装 Skyline Speeder。
- 新增 `speed --skyline` / `speed --skyline-status` / `speed --skyline-rollback` 及 TCP 子菜单入口。
- Skyline 阶段使用 `--prebuilt` 预编译 release，不在目标机安装 clang、LLVM 或 Rust 编译工具链。
- Skyline 安装前检查 `bpftool` 和 `tcp_cubic`；缺失 `bpftool` 时自动安装 `linux-tools-common`、`linux-tools-generic`，无法加载或验证 `cubic` 时终止。
- 取消 Skyline 模块和 RACK RTO 的自动调参；保留 STUN RTT 探测，并在探测完成后让用户选择参数档。
- 增加 usage.md 保守 / 默认 / 激进 / 旧默认（高随机丢包）四档交互选项，以及只调整 `guardrail-gain`、只调整 `cruise-pacing-gain` 或同时调整两者的选项；应用前完整覆盖模块参数（含 `min-cwnd-packets`）。
- Skyline RTT 探测面向中国大陆方向长 RTT / 随机丢包链路：使用 `stun.hitv.com:3478` 的指定三网 IP STUN 实测结果供用户选择档位参考。
- STUN 默认直接测试 `175.6.157.109:3478`、`116.162.157.194:3478`、`111.8.4.248:3478`，记录真实请求/响应 RTT、响应率、丢失率和抖动，按丢失率优先、RTT 次之取最差目标。
- 缺少 `tcpdump`、`turnutils_stunclient`、`ip` 或 `timeout` 时自动安装 `tcpdump`、`coturn`、`iproute2`、`coreutils`；不再使用 `hping3` 或 ICMP ping 推断 RTT。
- 三个 STUN 目标均无响应时记录回退 RTT 并交由用户选择；不自动设置自定义 RTO。
- 四档配方中除 `max-pacing-mbps` 外的 14 个参数严格照抄 usage.md「四档现成配方」；`max-pacing-mbps` 按机器上行带宽动态计算（实测/手动带宽 × 档位增益 × 丢包补偿 × 1.1），不再照抄配方的固定 1200/2000，避免高带宽机器被硬上限卡住。
- 新版 Skyline `install.sh` 默认源码构建；Speed Slayer 明确使用 `--prebuilt`，支持 `SKYLINE_RELEASE` 固定 release 和 `SKYLINE_ARTIFACT_URL` 指定本地/镜像 artifact，并兼容 SHA256 校验与升级保留配置行为。
- 仅在 Skyline 安装流程内增加带宽来源询问：选择 Ookla Upload 测速或手动填写上行带宽；手动选项跳过测速，不影响其他测速流程。`SPEED_BANDWIDTH_MBPS` 显式设置时跳过询问。
- 增加 `SKYLINE_STUN_HOST`、`SKYLINE_STUN_TARGETS`、`SKYLINE_STUN_PORT`、`SKYLINE_STUN_PROBE_COUNT`、`SKYLINE_STUN_TIMEOUT`、`SKYLINE_STUN_INTERVAL` 及 profile 探测明细记录。

### Documentation
- README 增加 Skyline Speeder 中国大陆方向 RTT 探测、官方参数基线、动态 RTO cgroup 作用域、DSCP 安全边界、回滚说明和环境变量说明。

## v1.0.0 - 2026-04-28

### Added
- 正式稳定版发布。
- README 正式化与项目说明美化。
- 鸣谢 @Eric86777 的 TCP 调优思路、NodeSeek 帖子与 vps-tcp-tune 仓库。

### Changed
- 版本号从 `v0.9.0-beta` 升级为 `v1.0.0`。
- README 聚焦快速开始、控制台、TCP 智能调优、Argo VMess WebSocket、诊断修复与更新说明。

### Notes
- v1.0.0 已通过实机测试，后续进入 bugfix 与兼容性增强阶段。

## v0.9.0-beta - 2026-04-28

### Added
- Speed Slayer 控制台与 `speed` 快捷命令。
- 一键完整流程：TCP 智能调优 + Argo VMess WebSocket 节点部署。
- XanMod / BBR v3 内核安装与重启后自动续跑。
- TCP 智能调优：内存/SWAP 检测、Speedtest 带宽探测、动态 buffer、FQ 队列、limits、DNS、IPv6 策略。
- 原生 Argo VMess+WS：cloudflared + Xray + Nginx + systemd。
- VMess URL、Base64、Clash、Shadowrocket、Auto 订阅生成。
- `speed --doctor` 全链路诊断。
- `speed --logs` 日志菜单。
- `speed --repair` 重复安装修复。
- `speed --speedtest` Ookla Speedtest 测速。
- `speed --netcheck` 网络连通性检测。
- 安装完成结果页与 CDN 优选提示。

### Changed
- 首页 UI 中文化与控制台二级菜单收拢。
- 自更新优先使用 GitHub API raw contents，减少 raw CDN 缓存影响。
- TCP 调优前台分阶段显示并同步写入日志。
- 重复安装前自动清理旧服务、旧进程与旧配置。

### Fixed
- 修复 `printf` 百分号导致脚本退出。
- 修复 VMess-only 校验误判 `vmess-ws` 为 `ss-ws` 残留。
- 修复 XanMod 包名硬拼导致的安装验证失败，改为 apt 候选探测与 fallback。
- 修复内核安装完成后未交互确认重启的问题。
- 修复更新提示把旧版本误判为新版本的问题。
- 修复终端 UI 颜色变量未定义问题。

### Notes
- 这是 Beta 版本，主流程已可用；建议继续进行多系统实机回归。
