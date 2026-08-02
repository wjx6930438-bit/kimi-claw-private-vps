# AI 辅助部署：能力边界与三种入口

本页说明如何让 Codex、Claude Code 或 Kimi Code **辅助完成 Kimi Claw Linux 主机内部的步骤**。它们可以执行只读预检、安装并启动 Tailscale、发起入网以及开启 Tailscale SSH，但不能替代端到端人工验收。

> **服务器端就绪不等于部署完成。** Tailscale 网页授权、Tailnet Policy、第二台设备真实 SSH 登录、公网 TCP 22 负向测试和重启复测均为 `manual-required`。

## 共同边界

三种方法都必须遵守以下约束：

1. 只在已经打开且可恢复的 Kimi Web Terminal 内辅助服务器端步骤。
2. 先做只读预检；受支持的 Linux、root 或免密 sudo、systemd、`/dev/net/tun`、出站 HTTPS 缺一项就停止。
3. 只使用 Tailscale 官方安装源；不把某个发行版的软件源硬套到其他发行版。
4. 主路径使用 Tailscale SSH，不安装或修改传统 OpenSSH，不开放公网 TCP 22。
5. 不配置 Funnel、Serve、Exit Node、子网路由，不接管系统 DNS 或默认路由。
6. 不使用 `StrictHostKeyChecking=no`、`tailscale up --force-reauth` 或任何跳过权限检查的模式。
7. 不把“命令退出码为零”“服务为 active”或“节点显示 Online”冒充第二台设备已经成功登录。

## 五个人工关口

| 关口 | 为什么必须由本人完成 | 结果状态 |
|---|---|---|
| Tailscale 网页授权 | 涉及本人 Tailnet 身份和浏览器会话 | `manual-required` |
| Tailnet Policy | 必须合并并预览现有规则，不能由工具整份覆盖 | `manual-required` |
| 第二台设备 SSH | 服务器内部无法证明外部客户端真实可登录 | `manual-required` |
| 公网 TCP 22 负向测试 | 必须从未连接 Tailscale 的外部网络测试，并核对平台入口规则 | `manual-required` 或 `not-applicable` |
| 重启复测 | 重启会中断现有会话，必须先保留恢复入口并由本人授权 | `manual-required` |

设备的 Key Expiry 也需要在 Tailscale 管理台人工检查。不要在唯一远程入口中强制重新认证。

## 隐私规则

公开仓库、Issue、聊天摘要和截图中不得出现：

- 密码、验证码、MFA 恢复码；
- Tailscale 授权 URL、Auth Key、Cookie 或浏览器会话；
- SSH 私钥、公钥正文、Host Key 或指纹；
- 真实公网 IP、Tailnet IP、MagicDNS 全名、邮箱或设备 ID；
- `tailscaled.state`、OpenClaw/Kimi token、credentials 或环境变量值。

仓库中的 Prompt 只含 `CHANGE_ME_ADMIN_USER`、`CHANGE_ME_NODE_NAME` 等占位符。请在私有会话中替换，不要提交替换后的个人副本。

## 方法选择

| 方法 | 适用入口 | 执行模型 | 主要限制 |
|---|---|---|---|
| Codex Browser | 尚未建立 SSH，只能从已登录的 Kimi 网页 Terminal 开始 | 浏览器交互、分阶段确认 | 必须保留登录状态；授权和外部验收由本人完成 |
| Claude Code | 已进入 Kimi Terminal | **交互批准优先** | 不使用跳过审批；非交互 Auto 只可视为实验性路径 |
| Kimi Code | 已进入 Kimi Terminal，且当前为 root 或 `sudo -n true` 成功 | `kimi -p` 已经是 Auto | Bash stdin 不支持密码提示；不能叠加 `--auto`、`--yolo` 或 `--plan` |

## 方法 A：Codex Browser 交互执行

使用 [Codex Browser Prompt](../prompts/codex-browser.txt)。

1. 在 Codex 桌面版中使用 Browser 打开已经登录的 Kimi Claw 页面；若登录状态在受支持的 Chrome 会话中，再使用对应的 Chrome 入口。
2. 在 Prompt 私有副本顶部替换 `ADMIN_USER` 和 `NODE_NAME`。
3. 粘贴完整 Prompt。
4. Codex 先做只读预检，并在修改系统前等待你明确回复“确认部署”。
5. Tailscale 输出一次性授权 URL 后，Codex 必须暂停，由你本人完成授权。
6. Policy、第二台设备登录、公网 22 负向测试和重启均保留为人工步骤。

不要让 Codex 读取浏览器 Cookie、导出登录信息或把授权 URL 写入摘要。

## 方法 B：Claude Code 交互批准优先

使用 [Claude Code Prompt](../prompts/claude-code.txt)。先在 Kimi Terminal 中确认当前为 root 或免密 sudo，然后从仓库根目录启动交互会话：

```bash
ADMIN_USER='CHANGE_ME_ADMIN_USER' \
NODE_NAME='CHANGE_ME_NODE_NAME' \
claude "$(cat prompts/claude-code.txt)"
```

逐项审阅并批准系统修改。交互模式是可靠主路径；不要公开推荐 `--dangerously-skip-permissions`。

Claude Code 的非交互 Auto 可能拦截安装、systemd 或网络修改，即使账户支持也不保证完成。若被拦截，应回到交互会话，不要扩大权限或关闭安全检查。

## 方法 C：Kimi Code `-p`

使用 [Kimi Code Prompt](../prompts/kimi-code.txt)。先确认：

```bash
test "$(id -u)" -eq 0 || sudo -n true
```

只有命令成功时才运行：

```bash
ADMIN_USER='CHANGE_ME_ADMIN_USER' \
NODE_NAME='CHANGE_ME_NODE_NAME' \
kimi -p "$(cat prompts/kimi-code.txt)"
```

`kimi -p` 已经使用 Auto，不能再叠加 `--auto`、`--yolo` 或 `--plan`。Kimi Code 的 Bash 工具没有可用于输入 sudo 密码的交互式 stdin，因此只支持 root 或免密 sudo；不能把密码写进命令绕过这一限制。

若需要网页授权，任务应输出 `AUTH_REQUIRED` 并停止。本人授权后，使用相同的 `ADMIN_USER`、`NODE_NAME` 和 Prompt 重新运行。

## 服务器端完成后的人工验收

在另一台已加入同一 Tailnet 的设备上完成：

```bash
ADMIN_USER='CHANGE_ME_ADMIN_USER'
NODE_NAME='CHANGE_ME_NODE_NAME'
tailscale ping "$NODE_NAME"
tailscale ssh "$ADMIN_USER@$NODE_NAME"
```

随后逐项核对：

1. Tailnet Policy 只允许预期身份访问目标节点的 TCP 22，并只允许登录预期 Linux 用户。
2. 关闭测试客户端的 Tailscale 后，从外部网络确认公网 TCP 22 失败或超时；没有公网端点则记录 `not-applicable`。
3. 在 Tailscale 管理台核对目标节点的 Key Expiry。
4. 保持 Kimi Web Terminal 可用并备份重要文件后，才人工批准重启。
5. 重启后重新检查 `tailscaled`、节点 Online、第二台设备 SSH，以及原有 Kimi Claw/OpenClaw 服务。

只有这些项目全部得到真实证据后，才能把状态从 `server-side-ready` 更新为完整验收通过。
