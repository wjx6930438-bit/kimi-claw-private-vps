# Kimi Claw Private VPS Guide

把满足预检条件的 Kimi Claw 云主机配置成一个 **VPS-like Linux 节点**：电脑或手机加入同一 Tailnet 后，通过 Tailscale SSH 管理它；本方案不要求向公网开放 TCP 22。

> 这不是传统云 VPS，也不是“零交互一键部署”。root/sudo、systemd、TUN、持久化和公网入口都必须对每个实例单独验证。首次授权、Tailnet Policy、第二台设备登录、公网 22 负向测试和重启复测必须由人完成。

**社区维护教程，非 Kimi / Moonshot AI 或 Tailscale 官方项目。**

[快速开始](QUICKSTART.md) · [AI 辅助部署](docs/ai-assisted-setup.zh-CN.md) · [Policy 示例](templates/tailscale-policy-personal.hujson) · [安全边界](SECURITY.md)

## 你最终会得到什么

- 纯 Tailscale SSH 主路径，不要求安装 `openssh-server`。
- 使用非 root Linux 管理用户。
- 不接管 Kimi 原有 DNS，也不接受额外子网路由。
- 从第二台设备完成真实 SSH 登录。
- 有公网端点时，从 Tailnet 外部验证 TCP 22 失败或超时；没有公网端点时记录 `not-applicable`。
- 重启后重新验证节点、服务、SSH 和 Kimi Claw/OpenClaw。
- 保留 Kimi Web Terminal 作为恢复入口。

本流程**不会**自动安装、修改或关闭实例上原有的传统 OpenSSH。若 `sshd` 已经监听，必须另行审计平台入口控制、防火墙和公网可达性。

## 五项硬预检

本教程的 systemd 主路径要求同时满足：

1. 受支持的 Linux；
2. root 或免密 sudo；
3. PID 1 为 systemd，且 `systemctl` 可用；
4. `/dev/net/tun` 可用；
5. 能通过 HTTPS 访问 Tailscale 官方安装源。

运行：

```bash
bash scripts/preflight.sh
```

任何一项显示 `STOP`，就不要继续复制后面的安装命令。

## 最短主路径

完整命令、解释和停止条件见 [QUICKSTART.md](QUICKSTART.md)。主线只有六步：

1. 运行预检；
2. 创建非 root 管理用户；
3. 从官方源安装并启用 Tailscale；
4. 以 `--accept-dns=false --accept-routes=false` 加入自己的 Tailnet；
5. 保持 Web Terminal 在线，再开启 Tailscale SSH；
6. 在第二台设备完成登录、公网 22 负向测试和重启复测。

## 两道 Policy 门

Tailscale SSH 需要两类规则同时允许：

1. 源设备到目标设备 TCP 22 的网络访问；
2. 当前 Tailnet 身份登录指定 Linux 用户的 SSH 身份规则。

仓库提供的 [个人 Tailnet Policy 示例](templates/tailscale-policy-personal.hujson) 只是起点。它适用于个人拥有、未共享的节点；必须与现有 Policy 合并、预览并测试，不能整份覆盖。

## 四项必须人工完成的验收

AI 或服务器内脚本不能替你证明以下事项：

- Tailnet Policy 已按预期生效；
- 第二台设备完成了真实 SSH 登录；
- 公网 TCP 22 在 Tailnet 外部不可达，或实例没有公网端点而记录为 `not-applicable`；
- 重启后节点、文件、服务和 SSH 都恢复。

请使用 [验收模板](templates/acceptance-report.txt) 记录枚举结果，不要粘贴真实 IP、设备名、授权链接、密钥或终端原始输出。

## 隐私与自动化边界

公开仓库里绝不能出现：

- 密码、验证码、MFA 恢复码；
- Tailscale 授权 URL 或 Auth Key；
- SSH 私钥、`tailscaled.state`、Cookie；
- OpenClaw/Kimi token、credentials 或环境变量；
- 真实公网 IP、Tailnet IP、MagicDNS 全名、主机名和邮箱。

详见 [SECURITY.md](SECURITY.md)。

## 仓库内容

```text
.
├─ README.md
├─ QUICKSTART.md
├─ SECURITY.md
├─ SOURCES.md
├─ CHANGELOG.md
├─ LICENSE
├─ docs/
│  └─ ai-assisted-setup.zh-CN.md
├─ prompts/
│  ├─ codex-browser.txt
│  ├─ claude-code.txt
│  └─ kimi-code.txt
├─ scripts/
│  └─ preflight.sh
└─ templates/
   ├─ acceptance-report.txt
   └─ tailscale-policy-personal.hujson
```

## 当前产品边界

- Kimi 将 Kimi Claw 描述为云端部署的 OpenClaw；平台能力、计费和保留规则可能变化，以官方页面为准。
- Tailscale SSH 只接管发往 Tailscale IP 的 22 端口。它不会自动关闭已有 OpenSSH，也不能单独证明公网 22 已关闭。
- `tailscale set --ssh` 会让当前经 Tailscale IP 建立的 SSH 会话挂起，因此首次开启时必须保留 Web Terminal。
- `autogroup:member`、`autogroup:self` 和默认 Policy 的行为必须按当前 Tailnet 的实际配置核对。

官方资料和核对日期见 [SOURCES.md](SOURCES.md)。

## License

[MIT](LICENSE)。命令和配置按原样提供，不附带适用于所有 Kimi Claw 实例的保证。
