# Security and scope

本文件定义公开教程的安全边界与证据标准。它不是对任意Kimi Claw实例、Tailnet或公网环境的安全保证。

## 产品边界

- Kimi Claw由平台部署和管理。本教程把满足前提的Linux环境作为**VPS-like节点**使用，不把它描述成具有独立SLA、固定公网IP、安全组和完整救援控制台的传统云VPS。
- root/免密sudo、systemd、`/dev/net/tun`、出站HTTPS、文件持久化和重启行为必须逐实例验证。
- Kimi当前产品、套餐、计费和数据保留说明可能变化，发布时应重新核对官方页面并标注核对日期。
- `--accept-dns=false --accept-routes=false`用于减少DNS和额外路由改动变量，不保证会话绝不断开。

## 主路径边界

主路径只使用Tailscale SSH：

- 不安装、启用、关闭或修改传统OpenSSH；
- 不修改`sshd_config`、`authorized_keys`、系统防火墙或平台入口规则；
- 不启用Funnel、Serve、Exit Node或子网路由；
- 不把TCP 22开放到公网作为故障绕行方案；
- 保留Kimi Web Terminal作为恢复入口。

Tailscale SSH只接管发往Tailscale IP的22端口。它不会关闭已有OpenSSH，已有普通SSH连接可能继续工作。因此，“只通过Tailscale管理”和“公网22不可达”必须通过已有监听审计、平台入口检查（若可用）和Tailnet外部负向测试共同确认。

执行`tailscale set --ssh`会使现有、经Tailscale IP建立的SSH会话挂起。首次开启必须从Kimi Web Terminal操作，并保留恢复入口。

## 自动化边界

服务器内部可以完成：

- 只读预检；
- Tailscale下载安装和服务检查；
- 创建本地管理用户；
- 发起Tailnet设备授权；
- 请求开启Tailscale SSH；
- 输出不含地址和凭证的本机状态。

以下事项必须保持`manual-required`，服务器或AI不能自行宣布通过：

| 项目 | 为什么必须人工或外部完成 |
|---|---|
| `TAILNET_DEVICE_AUTH` | 需要本人在浏览器登录并批准设备 |
| `TAILNET_POLICY` | 需要查看现有Policy、合并、预览并保存 |
| `DEVICE_KEY_EXPIRY` | 需要本人根据设备用途在Machines页面决定 |
| `CLIENT_SSH_TEST` | 必须从另一台Tailnet设备建立真实会话 |
| `PUBLIC_IPV4_TCP22_TEST` | 必须从关闭Tailscale的外部网络测试 |
| `PUBLIC_IPV6_TCP22_TEST` | 同上；无对应公网端点可记`not-applicable` |
| `ONLY_TAILSCALE_CONFIRMED` | 依赖监听、平台入口和外部测试的联合证据 |
| `REBOOT_TEST` | 会中断服务，且必须复测客户端和文件状态 |
| `KIMI_OPENCLAW_AFTER_REBOOT` | 需要本人检查平台端实际功能 |

如果Agent把这些字段直接写成`yes`，结果应视为无效，而不是自动化成功。

## Tailnet Policy边界

Tailscale SSH需要同时允许：

1. 源到目标TCP 22的网络访问；
2. 对目标本地Linux用户的SSH身份访问。

`templates/tailscale-policy-personal.hujson`使用`autogroup:member`和`autogroup:self`，只适合作为个人拥有、未共享节点的起点。节点一旦被分享，受邀外部用户可能进入相关身份范围；多用户、共享节点或已有服务的Tailnet必须重新设计规则。

模板是最小完整示例，不是补丁。任何现有Policy都必须先备份，再合并、预览和测试，禁止整份覆盖。

## 公网22证据边界

以下内容均不能单独证明公网22不可达：

- `tailscaled`为`active`；
- Tailscale SSH能够登录；
- 本机`ss`没有看到预期监听；
- AI或服务器脚本返回`yes`；
- 平台没有显示公网地址。

适用实例必须从关闭Tailscale的独立外部网络分别测试公网IPv4和IPv6。无公网端点记录`not-applicable`。一次测试失败只证明该测试网络视角下不可达，不应写成绝对安全保证。

## 重启和持久化证据边界

平台关于持续运行或数据保留的产品说明不能替代实例验收。只有实际重启后同时确认以下项目，才能称该次实例“持久化验收通过”：

- `tailscaled`仍为active、enabled；
- 节点重新Online；
- 另一台设备能够重新SSH；
- 重要文件仍存在；
- Kimi Claw/OpenClaw功能正常。

这仍不是独立SLA或永久运行保证。

## 公开资料红线

不得进入Git、发布包、公开截图、Issue、聊天或普通同步笔记：

- 密码、验证码、MFA恢复码；
- Tailscale授权URL、Auth Key及`tailscaled.state`；
- SSH私钥、真实公钥、Host Key和`known_hosts`；
- Cookie、浏览器Profile、Local/Session Storage；
- Kimi/OpenClaw Token、Credentials、环境变量和私有配置；
- 真实公网IP、Tailnet IP、MagicDNS全名、主机名、邮箱和原始状态输出；
- 未脱敏的日志、截图、备份和验收证据。

公开文档只保存布尔或枚举结果。真实证据应放在仓库之外的私有目录。

## 报告问题

- 普通文档错误可以提交公开 Issue，但只提供脱敏、可复现的最小信息。
- Issue、Discussion 和 Pull Request 中禁止粘贴授权 URL、真实地址、设备状态全文、截图原图、密钥或 Token。
- 若仓库已启用 GitHub Private Vulnerability Reporting，潜在安全问题优先通过该入口提交；未启用时，只能先提交不含任何秘密的概括说明。
- 如果秘密已经进入 Git 历史，不要只删除当前文件；立即撤销对应凭证，并在公开前重写受影响历史。

## 禁止的捷径

- 不使用`StrictHostKeyChecking=no`；
- 不因自动化受阻而开放公网22；
- 不在唯一远程会话中执行`tailscale up --force-reauth`；
- 不让Agent自行修改Tailnet Policy或重启；
- 不把“服务已启动”写成“端到端部署完成”；
- 不把“当前官方宣传24/7”写成独立SLA或永久可用。

## 官方依据

- [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh)
- [Tailscale Grants示例](https://tailscale.com/docs/reference/examples/grants)
- [Tailscale Key Expiry](https://tailscale.com/docs/features/access-control/key-expiry)
- [Kimi Claw产品说明](https://www.kimi.com/help/kimi-claw/overview)
- [Kimi会员与云主机计费说明](https://www.kimi.com/help/membership/membership-pricing)

详细核对日期由仓库的`SOURCES.md`记录。
