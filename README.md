# Speed Slayer

<p align="center">
  <img src="assets/speed-slayer-cover.jpg" alt="Speed Slayer" width="100%">
</p>

>                               VPS 网络加速 · TCP 智能调优 · Argo 隧道 · VMess WebSocket 节点生成

**Speed Slayer** 是一个面向 VPS 的网络加速与节点部署工具。它把 **XanMod / BBR v3 / TCP 智能调优**、**Cloudflare Argo Tunnel**、**VMess WebSocket 节点生成**、**诊断修复** 和 **交互式控制台** 收敛到一套清晰、可重复执行的流程里。

<p align="center">
  <strong>斩断延迟，撕开隧道，释放节点。</strong>
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-v2.0.8-22c55e">
  <img alt="Shell" src="https://img.shields.io/badge/shell-bash-0891b2">
  <img alt="Platform" src="https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-f97316">
  <img alt="Status" src="https://img.shields.io/badge/status-stable-16a34a">
</p>

---

## 适合谁用

- 想给 Debian / Ubuntu VPS 做 TCP 网络优化。
- 想一键部署 Cloudflare Argo + VMess WebSocket 节点。
- 想把 TCP 调优和节点生成分开执行。
- 想要可诊断、可重装、可卸载的 VPS 网络工具。
- 使用容器小鸡 / IPv6 小鸡，需要脚本能自动降级处理。

---

## 核心能力

- **完整流程**：TCP 调优 + Argo VMess WebSocket 节点部署。
- **分流程执行**：可单独执行 TCP 调优，也可单独生成 VMess+Argo 节点。
- **XanMod / BBR v3**：自动检测内核状态，安装内核组件，并支持重启后续跑。
- **容器降级模式**：容器环境不强装宿主机内核，只应用容器内可生效配置。
- **智能 TCP buffer**：根据 Speedtest 上传带宽推荐缓存档位，并允许手动选择。
- **Skyline Speeder 后置优化**：可在已有 TCP 调优完成后安装新型 BPF 优化，目标机使用预编译 release，不安装 clang / LLVM / Rust 编译工具链；运行前自动检查 `bpftool`，缺失时安装系统 BPF 工具包；默认针对中国大陆长 RTT / 随机丢包链路生成参数。
- **原生 Argo VMess+WS**：使用 `cloudflared + Xray + Nginx + systemd`，不依赖 ArgoX 安装链。
- **订阅输出**：生成 VMess URL、Base64、Clash、Shadowrocket、Auto 订阅。
- **交互控制台**：主菜单、子菜单、返回上级、日志查看、诊断修复一体化。
- **重复安装友好**：自动清理旧服务、旧进程、旧配置，并保留备份。
- **安全卸载**：可移除 Speed Slayer 相关内容，但不会自动删除 XanMod 内核。

---

## 前置依赖

Speed Slayer 是 Bash 脚本。新机器至少需要具备：

- `bash`
- `curl` 或 `wget`
- `ca-certificates`
- `sudo` 或 root 权限

Debian / Ubuntu 最小化系统可先执行：

```bash
apt update && apt install -y bash curl wget ca-certificates
```

如果当前不是 root，请先切换：

```bash
sudo -i
```

确认基础命令存在：

```bash
bash --version
curl --version
```

然后再执行下面的 Speed Slayer 安装命令。

---

## 快速开始

### 进入主菜单

```bash
bash <(curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh)
```

这条命令会安装 / 刷新 `speed` 快捷命令，并进入控制台。

如果你的环境不支持 `<(...)`：

```bash
curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh -o /tmp/speed-install && bash /tmp/speed-install
```

---

### 完整流程：TCP + Argo

```bash
bash <(curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh) --all
```

或安装后执行：

```bash
speed --all
```

---

### 只做 TCP 调优

```bash
bash <(curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh) --tcp
```

或安装后执行：

```bash
speed --tcp
```

---

### 只生成 VMess+Argo 节点

```bash
bash <(curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh) --argo
```

或安装后执行：

```bash
speed --argo
```

---

## 控制台

执行：

```bash
speed
```

主菜单：

```text
『Speed Slayer 控制台』

1. Speed Slayer TCP+Argo 🚀
2. 一键TCP调优
3. 一键Vmess+Argo 节点生成
4. 诊断与日志
5. 修复/清理/卸载
6. 更新
0. 退出
```

交互规则：

- 主菜单输入 `0`：退出脚本。
- 子菜单输入 `0`：返回主菜单。
- 查看状态、查看节点、查看日志、诊断等操作执行完后，会提示按回车返回当前子菜单。
- 如果存在续跑状态，执行 `speed` 会自动继续当前流程。

TCP 子菜单包含：

```text
1. 查看 TCP / BBR / 内核状态
2. 执行 TCP 优化
3. TCP 优化 + Skyline Speeder 后置优化
4. 单独安装 / 手动选择 Skyline 配置
5. 查看 Skyline Speeder 状态
6. 重启后继续安装
7. 回滚 Skyline Speeder 特殊优化
0. 返回主页
```

---

## 常用命令

```bash
speed                  # 无续跑状态进入主菜单；有续跑状态自动继续当前流程
speed --menu           # 安装/刷新 speed 快捷命令并进入主菜单
speed --version        # 查看版本
speed --update-self    # 更新 speed 自身

speed --all            # 完整流程：TCP 调优 + Argo 节点
speed --force-all      # 等同 speed --all
speed --tcp            # 单独执行 TCP 调优
speed --tcp-skyline    # 执行已有 TCP 调优，然后安装并手动选择 Skyline 配置
speed --skyline        # 仅安装并手动选择 Skyline 配置（免编译工具链）
speed --skyline-status # 查看 Skyline Speeder 运行状态
speed --skyline-rollback # 卸载 Skyline 并回滚特殊优化配置
speed --optimize       # 等同 speed --tcp
speed --argo           # 单独部署 Argo VMess+WS 节点
speed --continue       # 根据续跑状态继续当前流程

speed --doctor         # 全链路诊断
speed --health         # 安装后健康检查
speed --logs           # 查看日志菜单
speed --speedtest      # Ookla Speedtest 测速
speed --netcheck       # DNS / GitHub / Cloudflare / 出站连通性检测

speed --repair         # 清理残留并重装 Argo VMess+WS
speed --clear-state    # 清理重启续跑状态
speed --uninstall      # 删除 / 卸载 Speed Slayer
```

---

### Skyline Speeder 后置优化

在已有 TCP 调优完成后，执行：

```bash
speed --skyline
```

如果希望一次完成“已有 TCP 调优 + Skyline Speeder”，执行：

```bash
speed --tcp-skyline
```

该阶段会：

1. 检查 Debian / Ubuntu、6.12+ 内核、内核 BTF 和 cgroup v2。
2. 检查 `bpftool`；如果缺失，执行 `apt install -y linux-tools-common linux-tools-generic`（前置步骤会先刷新 APT 索引），安装后仍找不到命令则终止。
3. 执行 `modprobe tcp_cubic`，确认内核的可用拥塞控制列表包含 `cubic`；模块无法加载或内核没有 `cubic` 时立即失败，不继续安装 Skyline。
4. 将 `tcp_cubic` 写入 `/etc/modules-load.d/99-speed-slayer-cubic.conf`，确保重启后仍可加载，并记录本次变更。
5. 使用 `stun.hitv.com:3478` 的 STUN 协议探测三个指定 IP，输出每个目标的 Sent、Received、Packet loss、Min RTT、Avg RTT、Max RTT 和 Jitter。RTT 统计沿用参考脚本的 `success/sum/min/max/avg/loss` 逻辑；丢包率优先、平均 RTT 次之选择最差目标。
6. 依次让你选择 Skyline 官方 `docs/usage.md` 中的四档参数：保守档、默认档、激进档、旧默认档（高随机丢包链路）。RTT 只作为链路信息展示和选择参考，不根据 RTT 自动选择档位。
7. 选择档位后，再选择直接使用档位默认值，或只调整 `guardrail-gain`、只调整 `cruise-pacing-gain`、同时调整两者。`guardrail-gain` 校验范围为 `0-1.0`，`cruise-pacing-gain` 校验范围为不小于 `1.0`。
8. `max-pacing-mbps` 按机器上行能力动态计算：仅在 Skyline 安装流程内选择带宽来源——自动 Ookla Upload 测速，或跳过测速手动填写上行带宽（`SPEED_BANDWIDTH_MBPS` 可直接指定并跳过询问）。它是每条连接的速率硬上限，不是整机总限速。其余 14 个配方参数不做任何动态改动。
9. 应用前显示最终完整参数并要求确认。`ssctl set-module-config` 是全量覆盖接口，因此总是一次性写入配方 14 个参数（包括 `min-cwnd-packets`）加上动态 `max-pacing-mbps`，共 15 个；默认档的显式参数与新版 `ssctl` 内置默认值一致，即便升级机器的 `speeder.toml` 仍是旧值也能落到新默认档，所以不使用 `reset-module-config`。
10. 下载 Skyline Speeder 的 `install.sh` 并显式调用 `--prebuilt`：新版安装器默认源码编译，Speed Slayer 为免装 clang、LLVM、Rust 而选择预编译包；支持 `SKYLINE_RELEASE` 锁定版本和 `SKYLINE_ARTIFACT_URL` 指定本地/镜像包。安装器会校验可用的 SHA256；上游没有摘要时会提示仅依赖 TLS 信任。
11. 应用用户确认的模块参数，然后执行 `ssctl reset-rack-rto`，不再自动创建自定义 RACK RTO 策略，最后输出 `ssctl status`。

STUN RTT 探测默认使用 `stun.hitv.com:3478`，但会直接连接以下指定 IP，避免 DNS 结果变动影响三网比较：

- `175.6.157.109:3478`
- `116.162.157.194:3478`
- `111.8.4.248:3478`

该阶段会自动安装缺失依赖：`tcpdump`、`coturn`（提供 `turnutils_stunclient`）、`iproute2` 和 `coreutils`。STUN 请求和响应是真实 UDP 应用层往返，和 `hping3` 仅依靠 UDP/ICMP 报文的推断不同；它仍不是 iperf3 固定速率 UDP 打流，因此 RTT 不代表上传带宽，也不会被脚本用于自动选择参数档。Skyline 安装时会单独询问带宽来源（除非显式设置 `SPEED_BANDWIDTH_MBPS`），可选 Ookla Upload 测速或手动输入；这个选项不会出现在其他测速流程中。

四档配方的 14 个非上限参数逐项照抄 usage.md「四档现成配方」一节：

| 参数 | ① 保守 | ② 默认 | ③ 激进 | ④ 旧默认 |
|---|---:|---:|---:|---:|
| `max-cwnd-packets` | 50000 | 50000 | 100000 | 50000 |
| `max-queue-delay-ms` / `ratio` | 50 / 0.5 | 70 / 0.6 | 200 / 2.0 | 100 / 1.0 |
| `initial-cwnd-packets` | 50 | 100 | 200 | 100 |
| `min-cwnd-packets` | 4 | 4 | 4 | 4 |
| `min-rtt-window-s` | 30 | 30 | 30 | 10 |
| `bw-window-rtts` | 6 | 6 | 10 | 10 |
| `startup-plateau-rtts` / `growth-ratio` | 3 / 0.25 | 5 / 0.20 | 5 / 0.15 | 3 / 0.25 |
| `startup-gain` | 2.0 | 3.0 | 4.0 | 3.0 |
| `cruise-inflight-gain` | 1.5 | 3.0 | 3.0 | 2.0 |
| `cruise-pacing-gain` | 1.05 | 1.25 | 1.3 | 1.1 |
| `guardrail-gain` | 0.7 | 0.8 | 1.0 | 0.8 |
| `loss-inflation-max-ratio` | 0.10 | 0.10 | 0.5 | 0.5 |

选择“只调整 gain”时，仅 `guardrail-gain`（0-1.0）或 `cruise-pacing-gain`（≥1.0）在所选档位基础上被替换，其余参数仍按配方原值下发。

`max-pacing-mbps` 是唯一按机器动态计算的参数。usage.md 四档配方将它固定为 1200/2000，这是面向通用机器的值：低带宽机器上它远高于线路能力、不起作用，高带宽机器（>1Gbps）上它反而会反过来卡住档位的 pacing 目标速率。因此 Speed Slayer 按实测或手动填写的上行带宽计算：

```text
ceil(上行 Mbps × max(startup-gain, cruise-pacing-gain)
     × min(2, 1/(1-loss-inflation-max-ratio)) × 1.10)
```

增益取所选档位（含 gain 调整后）startup 与 cruise-pacing 的较大者；丢包补偿按 `1/(1-p)` 计，封顶 2 倍；再留 10% 余量。结果限制在 `1-100000Mbps`。参考值：默认档 100Mbps 上行算出 367，1000Mbps 算出 3667；激进档 100Mbps 算出 880（loss 0.5 触发 2 倍补偿）。Skyline 是闭环控制器，没有 bandwidth 参数；带宽值只用于推导这个硬上限，并写入档案备查。

可指定探测参数：

```bash
SKYLINE_STUN_HOST=stun.hitv.com speed --skyline
SKYLINE_STUN_TARGETS="175.6.157.109 116.162.157.194 111.8.4.248" speed --skyline
SKYLINE_STUN_PORT=3478 SKYLINE_STUN_PROBE_COUNT=10 speed --skyline
SKYLINE_STUN_TIMEOUT=3 SKYLINE_STUN_INTERVAL=1 speed --skyline
SKYLINE_RTT_FALLBACK_MS=180 speed --skyline
```

探测明细会写入 `skyline-profile.env` 和 `skyline-optimize.log`；无响应目标会按最差情况记录，不会被忽略。三个目标均无有效响应时仍使用回退 RTT 展示，并由你选择参数档，不会自动激进调参。

要求：Skyline Speeder 当前要求 Debian / Ubuntu、Linux 6.12+、`/sys/kernel/btf/vmlinux` 和 cgroup v2。该流程面向中国大陆方向的长 RTT、带宽充足、存在非拥塞性随机丢包的发送端链路；它不会改变 BGP、出口线路或客户端路由，只优化服务器发送端 TCP。预编译 release 不代表绕过内核要求；不满足条件时脚本会在安装前退出，不会改动 Skyline 配置。缺少 `bpftool` 时只安装系统工具包，不安装编译工具链。

当前 Speed Slayer 流程不会自动创建自定义 RACK RTO 策略；应用手动档位后会恢复 Skyline 默认 RTO。若你在 Skyline 中另行启用动态 RTO，它只对 `/sys/fs/cgroup/skyline-speeder` 中新建的连接生效。Skyline 的 `skyline_cc` 主体仍是全局新连接策略；如果要让某个服务获得动态 RTO，需要用 Skyline 提供的包装器启动：

```bash
sudo /opt/skyline-speeder/infra/run-in-skyline-cgroup.sh <服务启动命令...>
```

DSCP 重传标记不会被 Speed Slayer 自动开启。它只有在运营商、机房或上游网络明确提供 DSCP 值时才应该手动配置，否则可能被忽略、误分流或限速。确认拿到非零值后，可手动执行 `ssctl set-retransmit-dscp --dscp-value <值>`；不再使用时执行 `ssctl reset-retransmit-dscp`。

如果需要撤销这次特殊优化，执行：

```bash
speed --skyline-rollback
```

回滚会调用 Skyline 官方 `--uninstall`，停止并删除 Skyline 服务、程序与 BPF 对象，并恢复 Skyline 记录的安装前拥塞控制和队列配置。Speed Slayer 只删除本次新增的 `tcp_cubic` 持久化记录，不强制卸载正在使用的内核模块；`bpftool` 属于系统工具，回滚时会保留。回滚前会要求确认，回滚失败时会保留记录和日志，便于重试。

详细日志：`/etc/vps-argo-vmess/skyline-optimize.log`；手动选择后的参数档案：`/etc/vps-argo-vmess/skyline-profile.env`；回滚记录：`/etc/vps-argo-vmess/skyline-rollback.env`。可使用 `speed --skyline-status` 或 `speed --logs skyline` 查看状态。

可选环境变量：

- `SPEED_BANDWIDTH_MBPS=500`：直接指定 Skyline 动态 pacing 使用的上行带宽，不测速也不显示带宽来源选项。
- `SPEED_AUTO_SPEEDTEST=0`：在 Skyline 带宽来源选项中默认选择手动输入，并关闭现有自动测速路径。
- `SKYLINE_REPO=owner/repo`：指定 Skyline Speeder release 仓库。
- `SKYLINE_RELEASE=vX.Y.Z`：锁定具体 Skyline release。
- `SKYLINE_ARTIFACT_URL=/path/to/artifact.tar.gz`：沿用 Skyline 安装器的本地预编译包能力。
- `SKYLINE_STUN_HOST=stun.hitv.com`：记录 STUN 服务主机名，默认 `stun.hitv.com`。
- `SKYLINE_STUN_TARGETS="ip1 ip2 ip3"`：覆盖默认的三个指定 STUN IP。
- `SKYLINE_STUN_PORT=3478`：设置 STUN UDP 端口，默认 `3478`。
- `SKYLINE_STUN_PROBE_COUNT=10`：每个目标的 STUN 请求数量，默认 `10`。
- `SKYLINE_STUN_TIMEOUT=3` / `SKYLINE_STUN_INTERVAL=1`：每次请求超时和轮次间隔，单位秒。
- `SKYLINE_RTT_FALLBACK_MS=180`：全部 STUN 目标无响应时写入档案的保守 RTT，默认 `180ms`。

---

## 工作流程

### 完整流程

完整流程会依次执行：

1. 安装 / 刷新 `speed` 快捷命令。
2. 检测系统、内核、容器状态。
3. 如需要，安装 XanMod / BBR v3 内核组件。
4. 如果内核安装需要重启，保存续跑状态。
5. 重启后执行 `speed`，自动继续当前流程。
6. 执行 TCP 智能调优。
7. 部署 Argo VMess WebSocket 节点。
8. 生成 VMess URL 与订阅链接。
9. 执行健康检查并输出结果摘要。

### 单独 TCP 调优

单独 TCP 调优只处理网络优化，不会生成 Argo 节点。

如果 TCP 阶段安装了 XanMod 内核并要求重启，重启后执行：

```bash
speed
```

脚本只会继续 TCP 调优，不会自动进入 Argo 部署。

### 单独 Argo 节点生成

单独 Argo 流程只部署：

- `cloudflared`
- `Xray VMess + WebSocket`
- `Nginx WebSocket 反代与订阅接口`
- `systemd` 服务

不会执行 TCP 内核调优。

---

## TCP 智能调优

TCP 调优包含：

1. 检测内核、容器、SWAP、内存和网络状态。
2. 安装或识别 XanMod / BBR v3 内核。
3. 使用 Ookla Speedtest 获取上传带宽。
4. 根据带宽和内存推荐 TCP buffer。
5. 清理冲突 sysctl 配置。
6. 写入 BBR / FQ / TCP buffer / backlog / keepalive / limits / DNS 参数。
7. 应用 FQ 队列与持久化限制。
8. 输出 TCP 状态摘要。

### TCP buffer 推荐档位

| 上传带宽 | 推荐缓存 |
|---|---:|
| ≤100Mbps | 16MB |
| 100-500Mbps | 32MB |
| 500Mbps-1Gbps | 64MB |
| 1Gbps-2.5Gbps | 128MB |
| ≥2.5Gbps | 256MB |

脚本会根据内存做保护，避免小内存 VPS 因缓存过大导致压力过高。

### 手动指定带宽

```bash
SPEED_BANDWIDTH_MBPS=2000 speed --tcp
```

### 关闭自动测速

```bash
SPEED_AUTO_SPEEDTEST=0 speed --tcp
```

带宽来源说明：

- `measured`：Ookla Speedtest 实测。
- `manual`：手动指定。
- `default`：测速失败或关闭测速后的默认值。

---

## 容器与 IPv6 小鸡

部分容器小鸡、IPv6-only 小鸡无法安装或切换 XanMod 内核，这是宿主机限制，不是脚本本身失败。

Speed Slayer 会自动检测容器环境：

- **普通 VPS**：尝试安装 XanMod / BBR v3 内核，必要时提示重启。
- **容器环境**：跳过内核安装，进入无内核降级模式，只应用容器内可生效的优化项。

如果系统拒绝部分 sysctl 参数，脚本会保留可生效项并继续执行。

---

## VMess+Argo 输出内容

节点生成后会输出：

- VMess URL
- Base64 订阅
- Clash 订阅
- Shadowrocket 订阅
- Auto 订阅

查看节点信息：

```bash
speed --show-url
```

或进入控制台：

```text
3. 一键Vmess+Argo 节点生成
2. 查看节点/订阅信息
```

---

## 诊断与日志

常用诊断：

```bash
speed --doctor
speed --health
speed --logs
speed --netcheck
speed --speedtest
```

常见日志路径：

```text
/etc/vps-argo-vmess/install.log
/etc/vps-argo-vmess/kernel-install.log
/etc/vps-argo-vmess/tcp-optimize.log
/etc/vps-argo-vmess/speedtest.log
/etc/vps-argo-vmess/netcheck.log
/etc/vps-argo-vmess/skyline-optimize.log
/etc/argox/argo.log
/etc/argox/xray-error.log
```

XanMod 安装失败时，优先查看：

```bash
cat /etc/vps-argo-vmess/kernel-install.log
```

筛选关键日志：

```bash
grep -n "XanMod APT\|XanMod PKG\|selected suite\|no candidate\|ERR\|error\|failed" /etc/vps-argo-vmess/kernel-install.log
```

---

## 修复、重装与卸载

### 修复 Argo 安装

```bash
speed --repair
```

会清理 Argo 服务、旧进程和旧配置，然后重新部署 VMess+WS。

### 清理续跑状态

```bash
speed --clear-state
```

适合在中断安装、误进入续跑状态、想回到主菜单时使用。

### 卸载 Speed Slayer

```bash
speed --uninstall
```

会清理：

- `/usr/local/bin/speed`
- `/etc/vps-argo-vmess`（备份为 `.bak.<timestamp>`）
- `/etc/argox`（备份为 `.bak.<timestamp>`）
- `argo.service` / `xray.service`
- Speed Slayer 写入的 sysctl、systemd limits、DNS、IPv6 配置

注意：**不会自动卸载 XanMod 内核本身**，避免误删系统内核导致机器无法启动。

卸载确认默认为 `N`，必须明确输入 `y` 或 `yes` 才会执行。

---

## 更新

推荐：

```bash
speed --update-self
```

如果本机脚本损坏，可重新拉取安装入口：

```bash
curl -fsSL https://github.com/Suyunmeng/tcpspeed-optimization/raw/main/install.sh -o /tmp/speed-install && bash /tmp/speed-install
```

---

## CDN 优选建议

节点生成后，建议在本地运行 CloudflareSpeedTest，选择延迟更低、速度更稳的 CDN IP：

<https://github.com/XIU2/CloudflareSpeedTest>

---

## 鸣谢

特别感谢 **@Eric86777** 的 TCP 调优思路与实践参考。

- NodeSeek 帖子：<https://www.nodeseek.com/post-704739-1>
- 项目仓库：<https://github.com/Eric86777/vps-tcp-tune>

Speed Slayer 的 TCP 调优方向参考了他的思路，并在此基础上做了产品化控制台、续跑机制、诊断修复、Argo VMess WebSocket 部署与订阅输出等整合。

---

## 版本

当前正式版：`v2.0.8`

### v2.0.8

- NAT / LXC 环境自动跳过 Ookla Speedtest，避免卡在 `Cannot read from socket / Latency test failed`；改为手动选择上行带宽档位。
- 节点名默认改为 `国家代码-主机名-vmess-ws-argo`，例如 `US-tmobile-6BjoBc-vmess-ws-argo`；仍可用 `NODE_NAME=...` 覆盖。
- 控制台主页新增“查看节点/订阅信息”入口，节点信息不再藏在二级菜单里。

---

## License

MIT or repository default license. See repository files for details.
