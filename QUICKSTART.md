# Quickstart：Kimi Claw 接入 Tailscale SSH

本页只描述一条主路径：把通过预检的 Kimi Claw Linux 环境接入自己的 Tailnet，并使用 **Tailscale SSH** 登录。

- 这是一台 VPS-like Linux 节点，不是传统云 VPS。
- 本路径不安装、不配置、也不关闭传统 OpenSSH。
- 服务器内步骤可以脚本化；设备授权、Tailnet Policy、外部登录、公网 TCP 22 负向测试和重启验收必须由本人完成。
- 未完成外部验收前，只能说“目标是不开放公网 22”，不能说已经实现。

安全边界见 [SECURITY.md](SECURITY.md)。

## 0. 保留恢复入口

开始前必须同时满足：

1. Kimi Web Terminal 仍可用并保持打开；
2. 重要工作区已备份；
3. 不把当前会话当成唯一恢复入口；
4. 不在聊天、截图或公开日志中粘贴授权 URL、IP、设备名、邮箱、Token 或密钥。

`tailscale set --ssh` 可能让当前经 Tailscale IP 建立的 SSH 会话挂起。首次开启时应从 Kimi Web Terminal 操作。

## 1. 运行只读预检

在仓库根目录执行：

```bash
bash scripts/preflight.sh
```

只有最后一行是下面结果时才继续：

```text
PRECHECK_RESULT=PASS
```

本流程要求：Ubuntu/Debian、已验证架构、root 或免密 sudo、PID 1 为 systemd、可用的 `/dev/net/tun`，以及能访问 Tailscale 官方安装源的出站 HTTPS。

`WARN` 不代表公网安全。预检只报告已有 OpenSSH/TCP 22 监听，不会修改它们。

## 2. 设置并校验非秘密变量

下面示例使用中性默认值。若要更改，请只使用不含个人信息的名称，并在同一个 Bash 会话中继续后续服务器命令。

```bash
set -Eeuo pipefail

export ADMIN_USER="${ADMIN_USER:-kimiadmin}"
export NODE_NAME="${NODE_NAME:-kimi-private-vps}"

[[ "$ADMIN_USER" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || {
  printf 'ADMIN_USER 格式无效\n' >&2
  exit 1
}

[[ "$NODE_NAME" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] && [[ "$NODE_NAME" != *- ]] || {
  printf 'NODE_NAME 格式无效\n' >&2
  exit 1
}

if (( EUID == 0 )); then
  ROOT_CMD=()
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  ROOT_CMD=(sudo -n)
else
  printf '需要 root 或免密 sudo；停止。\n' >&2
  exit 1
fi
```

变量始终放在双引号中使用。不要把真实 IP、邮箱或账户标识写入仓库文件。

## 3. 创建非 root 管理用户

Ubuntu/Debian 的 `adduser` 会在当前终端要求设置本地密码。密码只在 Web Terminal 中输入，不写进命令、Prompt或文档。

```bash
if ! getent passwd "$ADMIN_USER" >/dev/null; then
  "${ROOT_CMD[@]}" adduser "$ADMIN_USER"
fi

"${ROOT_CMD[@]}" usermod -aG sudo "$ADMIN_USER"
getent passwd "$ADMIN_USER" | cut -d: -f1,6,7
id "$ADMIN_USER"
```

此步骤只创建本地 Linux 用户。Tailscale SSH 仍需后面的网络权限和 SSH 身份规则。

## 4. 从官方地址安装 Tailscale

本教程不使用 `curl | sh`。先下载脚本、人工查看，再执行：

```bash
INSTALLER_PATH="$(mktemp -t tailscale-install.XXXXXX)"
chmod 600 "$INSTALLER_PATH"
trap 'rm -f -- "${INSTALLER_PATH:-}"' EXIT

curl --fail --silent --show-error --location \
  --proto '=https' --proto-redir '=https' --tlsv1.2 \
  --max-time 30 \
  --output "$INSTALLER_PATH" \
  https://tailscale.com/install.sh

sed -n '1,9999p' "$INSTALLER_PATH"
printf '检查上面的官方安装脚本后，输入 RUN 继续： '
read -r INSTALL_CONFIRM
[[ "$INSTALL_CONFIRM" == RUN ]] || {
  printf '未确认，停止。\n' >&2
  exit 1
}

"${ROOT_CMD[@]}" sh "$INSTALLER_PATH"
rm -f -- "$INSTALLER_PATH"
trap - EXIT

"${ROOT_CMD[@]}" systemctl enable --now tailscaled.service
systemctl is-active --quiet tailscaled.service
systemctl is-enabled --quiet tailscaled.service
tailscale version
```

下载成功只证明安装源可达；最后三项通过才证明客户端和服务已安装、启动并设置为开机启动。

## 5. 加入 Tailnet

下面命令适用于尚未加入 Tailnet的新节点：

```bash
"${ROOT_CMD[@]}" tailscale up \
  --hostname="$NODE_NAME" \
  --accept-dns=false \
  --accept-routes=false
```

命令会显示敏感授权 URL：

1. 只在自己的浏览器打开；
2. 登录自己的 Tailscale 账户并批准该节点；
3. 不复制到聊天、文档、截图或发布包；
4. 在 Machines 页面人工确认节点 Online；
5. 人工决定该设备的 key expiry 设置。

`--accept-dns=false` 和 `--accept-routes=false`只减少系统DNS及额外路由变化，不保证绝不断线。

若节点此前已经加入 Tailnet，不要盲目重复运行`tailscale up`；先在私人终端核对当前状态，再使用当前版本支持的`tailscale set`参数调整。

## 6. 开启 Tailscale SSH

确认 Kimi Web Terminal 仍然可用后执行：

```bash
"${ROOT_CMD[@]}" tailscale set --ssh
systemctl is-active tailscaled.service
```

这里没有安装或修改`openssh-server`、`sshd_config`、`authorized_keys`、系统防火墙或平台入口规则。已有OpenSSH可能继续工作并可能仍对公网暴露；只有第9节的外部测试能提供相应证据。

## 7. 人工合并 Tailnet Policy

状态：**manual-required**。

Tailscale SSH需要两道规则同时允许：

1. 客户端到目标节点TCP 22的网络访问；
2. 当前Tailnet身份登录`ADMIN_USER`对应本地Linux用户的SSH身份规则。

`templates/tailscale-policy-personal.hujson`只适用于个人拥有且未共享的节点，是最小完整示例，不是可覆盖现有Policy的补丁。

操作要求：

1. 先备份当前Policy；
2. 若`ADMIN_USER`不是`kimiadmin`，在模板副本中替换该字符串；
3. 将所需规则合并进现有Policy；
4. 使用控制台预览和测试；
5. 保存后再做客户端登录。

没有控制台验证结果时，验收表必须保留`TAILNET_POLICY=manual-required`。

## 8. 从另一台设备真实登录

状态：**manual-required**。

客户端必须已安装Tailscale、登录同一Tailnet，并拥有SSH客户端。在客户端的私人终端设置目标；不要把值写入仓库：

```bash
export ADMIN_USER="${ADMIN_USER:-kimiadmin}"
: "${TAILSCALE_TARGET:?请在私人终端设置 TAILSCALE_TARGET 为 Tailnet IP 或已验证可解析名称}"

[[ "$ADMIN_USER" =~ ^[a-z][a-z0-9-]{0,30}$ ]] || exit 1
[[ "$TAILSCALE_TARGET" != -* ]] && [[ "$TAILSCALE_TARGET" != *[[:space:]]* ]] || exit 1

tailscale ping "$TAILSCALE_TARGET"
tailscale ssh "${ADMIN_USER}@${TAILSCALE_TARGET}"
```

如果客户端没有`tailscale ssh`子命令，可在Tailnet已经连通时使用标准SSH：

```bash
ssh "${ADMIN_USER}@${TAILSCALE_TARGET}"
```

不要使用`StrictHostKeyChecking=no`。出现Host Key变化时，应先从可信的Kimi控制台核对实例是否重建或密钥是否轮换。

登录后人工检查：

```bash
id
sudo -v
systemctl is-active tailscaled.service
```

服务器本机的退出码、`tailscale status`或服务`active`均不能替代这次真实登录。

## 9. 从Tailnet外部测试公网TCP 22

状态：**manual-required**或`not-applicable`。

必须使用独立外部网络，并先在测试设备上关闭Tailscale。公网地址只保存在私人终端变量中：

```bash
if [[ -n "${PUBLIC_IPV4:-}" ]] && ! command -v nc >/dev/null 2>&1; then
  printf 'PUBLIC_IPV4_TCP22_TEST=not-run\n'
elif [[ -n "${PUBLIC_IPV4:-}" ]]; then
  if nc -vz -w 5 "$PUBLIC_IPV4" 22; then
    printf 'PUBLIC_IPV4_TCP22_TEST=no\n'
  else
    printf 'PUBLIC_IPV4_TCP22_TEST=yes\n'
  fi
else
  printf 'PUBLIC_IPV4_TCP22_TEST=not-applicable\n'
fi

if [[ -n "${PUBLIC_IPV6:-}" ]] && ! command -v nc >/dev/null 2>&1; then
  printf 'PUBLIC_IPV6_TCP22_TEST=not-run\n'
elif [[ -n "${PUBLIC_IPV6:-}" ]]; then
  if nc -6 -vz -w 5 "$PUBLIC_IPV6" 22; then
    printf 'PUBLIC_IPV6_TCP22_TEST=no\n'
  else
    printf 'PUBLIC_IPV6_TCP22_TEST=yes\n'
  fi
else
  printf 'PUBLIC_IPV6_TCP22_TEST=not-applicable\n'
fi
```

- `yes` 只表示从本次独立外部网络连接失败或超时；`no` 表示端口可达，验收失败。
- `not-run` 表示测试工具缺失或尚未执行，不能据此宣称公网22未开放。
- 没有对应公网端点：记录`not-applicable`，不要为了测试临时开放端口。
- 若平台提供入口控制或防火墙界面，也要核对；不能假定Kimi提供传统云安全组。
- 单个外部网络的失败只能证明该测试视角下不可达，不构成互联网范围的绝对保证。

## 10. 重启验收

状态：**manual-required**。

只有已经完成备份、保留Web Terminal、成功从客户端登录，并确认平台存在恢复入口后，才使用平台支持的重启方式。不要让Agent自行重启。

重启后，在服务器私人终端检查：

```bash
systemctl is-active tailscaled.service
systemctl is-enabled tailscaled.service
```

随后从另一台设备重复第8节，并人工确认Kimi Claw/OpenClaw仍能正常响应、重要文件仍存在。未完成这些检查时，不能写“持久化完成”或“重启不掉”。

## 11. 最小回滚

以下操作会改变或中断远程访问，只能在Kimi Web Terminal或其他已验证恢复入口仍可用时执行。

关闭Tailscale SSH但保留Tailnet连接：

```bash
"${ROOT_CMD[@]}" tailscale set --ssh=false
```

阻止Tailnet设备主动连接本机：

```bash
"${ROOT_CMD[@]}" tailscale set --shields-up
```

完全退出Tailnet会立即切断该路径，只在明确决定回滚且恢复入口可用时执行：

```bash
"${ROOT_CMD[@]}" tailscale logout
```

## 完成定义

复制`templates/acceptance-report.txt`到不公开的本地证据目录。只有所有硬条件为`yes`、适用的公网测试为`yes`或`not-applicable`，且所有`manual-required`都由本人实际完成后，才能把`FINAL_STATUS`改为`ready`。
