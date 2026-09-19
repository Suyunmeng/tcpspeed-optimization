# CHANGELOG

## Unreleased

### Added
- 新增 `speed --tcp-skyline`，在已有 TCP 调优完成后可选安装 Skyline Speeder。
- 新增 `speed --skyline` / `speed --skyline-status` / `speed --skyline-rollback` 及 TCP 子菜单入口。
- Skyline 阶段使用 `--prebuilt` 预编译 release，不在目标机安装 clang、LLVM 或 Rust 编译工具链。
- Skyline 安装前检查 `bpftool` 和 `tcp_cubic`；缺失 `bpftool` 时自动安装 `linux-tools-common`、`linux-tools-generic`，无法加载或验证 `cubic` 时终止。
- 根据内存、上传带宽和基线 RTT 自动生成并应用 Skyline 模块与 RACK RTO 参数，保存参数档案和独立日志。
- Skyline 自动调参改为面向中国大陆方向长 RTT / 随机丢包链路：使用大陆目标 RTT 中位数，不再探测 `1.1.1.1` Cloudflare 边缘 RTT。
- 调参基线对齐 Skyline 官方生产档：固定 `startup/cruise/guardrail/loss` 系数，使用 20ms/200ms RTO 下限边界和 3x/6x RTO 退避上限。
- 增加动态 RTO cgroup 作用域提示，明确该功能只对 `/sys/fs/cgroup/skyline-speeder` 内新建连接生效；不自动写入 DSCP，避免误用未知运营商策略。

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
