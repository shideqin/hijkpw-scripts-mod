# hijkpw-scripts-mod

本仓库部分脚本基于网络跳越 hijk 相关脚本进行修改。

主要针对原脚本中的服务器检测、`hostip`、网络环境检测等逻辑进行调整，减少对原网站的依赖，并对部分脚本进行适配和维护。

---

## 一、快速安装

### 1. Xray VLESS + REALITY + XTLS Vision

**推荐新服务器使用。**

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod3.sh)
```

协议：

```text
VLESS
+
REALITY
+
XTLS Vision
```

Flow：

```text
xtls-rprx-vision
```

---

### 2. Xray Legacy

旧版 Xray / XTLS 配置兼容版本。

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod2.sh)
```

---

### 3. V2Ray

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2.sh)
```

---

### 4. V2Ray IPv6 + Cloudflare

适用于 IPv6 VPS、Cloudflare CDN 等特殊网络环境。

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2_ipv6_cloudflare.sh)
```

---

### 5. Trojan

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan_mod2.sh)
```

---

### 6. Trojan-Go

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan-go_mod2.sh)
```

---

# 二、脚本列表

当前仓库主要维护以下脚本：

| 脚本                              | 类型        | 说明                            |
| ------------------------------- | --------- | ----------------------------- |
| `xray_mod3.sh`                  | Xray      | VLESS + REALITY + XTLS Vision |
| `xray_mod2.sh`                  | Xray      | Legacy / 旧版 XTLS              |
| `v2ray_mod2.sh`                 | V2Ray     | V2Ray 多合一脚本                   |
| `v2ray_mod2_ipv6_cloudflare.sh` | V2Ray     | IPv6 + Cloudflare             |
| `trojan_mod2.sh`                | Trojan    | Trojan 安装脚本                   |
| `trojan-go_mod2.sh`             | Trojan-Go | Trojan-Go 安装脚本                |

---

# 三、Xray

## 3.1 xray_mod3.sh

`xray_mod3.sh` 是当前新版 Xray 部署脚本。

主要用于：

```text
VLESS + REALITY + XTLS Vision
```

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod3.sh)
```

### 主要功能

* 自动安装 Xray
* 自动检测操作系统
* 自动检测服务器 IPv4
* 自动检测 443 端口
* 自动生成 UUID
* 自动生成 REALITY X25519 密钥
* 自动生成 Short ID
* 自动生成服务器配置
* 自动生成 VLESS 客户端链接
* 自动修复配置文件权限
* 自动检查 JSON 配置
* 自动执行 Xray 配置测试
* 自动启动 / 重启 Xray
* systemd 服务管理
* 查看 Xray 状态
* 查看 Xray 配置
* 查看客户端参数
* 查看 Xray 日志
* 修复配置权限
* 卸载 Xray

### 使用协议

```text
Protocol:
VLESS

Transport:
TCP / RAW

Security:
REALITY

Flow:
xtls-rprx-vision

Port:
443
```

### XTLS Vision

客户端使用：

```text
flow=xtls-rprx-vision
```

服务器端：

```json
{
  "clients": [
    {
      "id": "UUID",
      "flow": "xtls-rprx-vision"
    }
  ]
}
```

---

## 3.2 xray_mod3.sh 菜单

运行脚本：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod3.sh)
```

进入菜单：

```text
============================================================
        Xray VLESS + REALITY + XTLS Vision
============================================================

1. 安装 / 重装 VLESS + REALITY
2. 查看 Xray 状态
3. 查看 Xray 配置
4. 查看客户端参数
5. 重启 Xray
6. 查看 Xray 日志
7. 修复配置权限
8. 卸载 Xray
0. 退出
```

---

# 四、xray_mod3.sh 配置说明

默认配置结构：

```text
VLESS
 │
 ├── TCP / RAW
 │
 ├── REALITY
 │
 └── XTLS Vision
        │
        └── xtls-rprx-vision
```

主要参数：

```text
Address
Port
UUID
Flow
SNI
Fingerprint
Public Key
Short ID
```

安装过程中会自动生成：

```text
UUID
REALITY Private Key
REALITY Public Key
Short ID
```

并生成客户端 VLESS 链接。

---

# 五、REALITY 参数说明

REALITY 服务端会生成：

```text
Private Key
Public Key
Short ID
```

其中：

### Private Key

服务器私钥。

**属于敏感信息，不要公开。**

### Public Key

客户端使用。

例如：

```text
pbk=xxxxxxxxxxxxxxxx
```

### Short ID

客户端使用。

例如：

```text
sid=xxxxxxxx
```

### SNI

客户端需要与服务器配置中的 `serverNames` 对应。

例如：

```text
sni=speed.cloudflare.com
```

---

# 六、VLESS 客户端链接

`xray_mod3.sh` 安装完成后会自动生成类似：

```text
vless://UUID@SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=SERVER_NAME&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&headerType=none#VLESS-REALITY-Vision
```

可以用于支持 VLESS + REALITY + Vision 的客户端。

例如：

```text
v2rayN
v2rayNG
```

实际客户端参数以脚本安装完成后生成的配置为准。

---

# 七、xray_mod2.sh

`xray_mod2.sh` 为旧版 Xray / XTLS 兼容脚本。

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod2.sh)
```

主要用于：

* 旧服务器
* 历史 Xray 配置
* 旧版 XTLS
* 已经部署旧版 Xray 的环境
* 兼容历史客户端

如果是新服务器部署 Xray，优先使用：

```text
xray_mod3.sh
```

---

# 八、V2Ray

## 8.1 v2ray_mod2.sh

V2Ray 多合一脚本。

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2.sh)
```

适用于：

* 常规 VPS
* V2Ray 部署
* IPv4 环境
* 常见 V2Ray 配置场景

---

# 九、V2Ray IPv6 + Cloudflare

## 9.1 v2ray_mod2_ipv6_cloudflare.sh

IPv6 + Cloudflare 特殊版本。

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2_ipv6_cloudflare.sh)
```

适用于：

* IPv6 VPS
* IPv6-only VPS
* IPv4 / IPv6 混合环境
* Cloudflare CDN
* 需要通过 Cloudflare 进行访问的环境

该脚本与普通：

```text
v2ray_mod2.sh
```

用途不同，因此单独保留。

---

# 十、Trojan

## 10.1 trojan_mod2.sh

Trojan 安装脚本。

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan_mod2.sh)
```

适用于：

```text
Trojan
```

协议部署。

---

# 十一、Trojan-Go

## 11.1 trojan-go_mod2.sh

Trojan-Go 安装脚本。

安装：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan-go_mod2.sh)
```

适用于：

```text
Trojan-Go
```

部署。

---

# 十二、Xray 常用命令

## 查看 Xray 状态

```bash
systemctl status xray
```

---

## 启动 Xray

```bash
systemctl start xray
```

---

## 停止 Xray

```bash
systemctl stop xray
```

---

## 重启 Xray

```bash
systemctl restart xray
```

---

## 设置开机启动

```bash
systemctl enable xray
```

---

## 查看 Xray 日志

```bash
journalctl -u xray -n 100 --no-pager
```

---

## 实时查看日志

```bash
journalctl -u xray -f
```

---

# 十三、检查 Xray 配置

Xray 配置文件：

```text
/usr/local/etc/xray/config.json
```

检查配置：

```bash
xray run -test -config /usr/local/etc/xray/config.json
```

如果显示：

```text
Configuration OK.
```

说明配置文件通过检查。

---

# 十四、Xray 文件位置

默认 Xray 程序：

```text
/usr/local/bin/xray
```

配置目录：

```text
/usr/local/etc/xray/
```

主配置：

```text
/usr/local/etc/xray/config.json
```

客户端参数：

```text
/usr/local/etc/xray/client-info.txt
```

备份目录：

```text
/usr/local/etc/xray/backup/
```

---

# 十五、检查 443 端口

Xray 默认使用：

```text
443
```

检查：

```bash
ss -lntp | grep ':443'
```

或者：

```bash
ss -lntp
```

如果发现：

```text
0.0.0.0:443
```

已经被其他程序占用，需要先处理端口冲突。

常见占用程序：

```text
nginx
apache
caddy
其他 Xray
其他代理程序
```

---

# 十六、Xray 配置权限

如果 Xray 日志出现：

```text
permission denied
```

例如：

```text
open /usr/local/etc/xray/config.json: permission denied
```

可以执行：

```bash
chown root:root /usr/local/etc/xray
chmod 755 /usr/local/etc/xray

chown root:root /usr/local/etc/xray/config.json
chmod 644 /usr/local/etc/xray/config.json
```

然后检查：

```bash
xray run -test -config /usr/local/etc/xray/config.json
```

如果配置测试通过：

```bash
systemctl restart xray
```

`xray_mod3.sh` 已经包含配置权限修复逻辑。

---

# 十七、防火墙

如果 Xray 已经正常启动，但是客户端无法连接，需要检查 VPS 防火墙和云服务器安全组。

确认开放：

```text
TCP 443
```

例如检查本机：

```bash
iptables -L -n
```

如果使用 firewalld：

```bash
firewall-cmd --list-ports
```

如果使用 UFW：

```bash
ufw status
```

同时检查云服务商控制台中的：

```text
安全组
Security Group
入站规则
```

---

# 十八、脚本目录结构

当前仓库建议保持以下结构：

```text
.
├── README.md
│
├── v2ray_mod2.sh
├── v2ray_mod2_ipv6_cloudflare.sh
│
├── xray_mod2.sh
├── xray_mod3.sh
│
├── trojan_mod2.sh
└── trojan-go_mod2.sh
```

---

# 十九、脚本用途总览

```text
                    hijkpw-scripts-mod
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
        V2Ray             Xray             Trojan
          │                 │                 │
     ┌────┴────┐       ┌────┴────┐           │
     │         │       │         │           │
   IPv4    IPv6+CF   Legacy   REALITY       Trojan
                       │       Vision
                       │
                    mod2      mod3
                                     
                                     
                         Trojan-Go
```

---

# 二十、推荐选择

## 新部署 Xray

使用：

```text
xray_mod3.sh
```

协议：

```text
VLESS + REALITY + XTLS Vision
```

---

## 旧 Xray 环境

使用：

```text
xray_mod2.sh
```

主要用于历史配置兼容。

---

## 普通 V2Ray

使用：

```text
v2ray_mod2.sh
```

---

## IPv6 + Cloudflare

使用：

```text
v2ray_mod2_ipv6_cloudflare.sh
```

---

## Trojan

使用：

```text
trojan_mod2.sh
```

---

## Trojan-Go

使用：

```text
trojan-go_mod2.sh
```

---

# 二十一、快速安装命令汇总

### Xray VLESS + REALITY + Vision

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod3.sh)
```

### Xray Legacy

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/xray_mod2.sh)
```

### V2Ray

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2.sh)
```

### V2Ray IPv6 + Cloudflare

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/v2ray_mod2_ipv6_cloudflare.sh)
```

### Trojan

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan_mod2.sh)
```

### Trojan-Go

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shideqin/hijkpw-scripts-mod/main/trojan-go_mod2.sh)
```

---

# 二十二、安全说明

请注意保护以下信息：

```text
UUID
Private Key
服务器 IP
密码
REALITY Private Key
其他认证信息
```

特别是：

```text
REALITY Private Key
```

**不要提交到 GitHub，也不要公开发布。**

客户端只需要使用：

```text
Public Key
Short ID
UUID
SNI
```

等必要参数。

---

# 二十三、使用说明

不同 VPS 服务商、操作系统和网络环境可能存在差异。

使用脚本前请确认：

1. VPS 网络正常
2. IPv4 / IPv6 状态正常
3. 防火墙规则正常
4. 云服务器安全组允许相关端口
5. 443 端口没有被其他服务占用
6. DNS 配置正常
7. 客户端支持对应协议

如果 Xray 服务启动失败，建议首先执行：

```bash
systemctl status xray --no-pager
```

然后：

```bash
journalctl -u xray -n 100 --no-pager
```

最后检查配置：

```bash
xray run -test -config /usr/local/etc/xray/config.json
```

---

# 二十四、项目来源

本仓库部分脚本基于网络跳越 hijk 相关脚本进行修改和维护。

感谢原作者以及相关社区贡献者。

本仓库并非原项目官方仓库。

---

# 二十五、License

请遵循原项目以及相关开源软件各自的许可证要求。

使用、修改和发布相关脚本前，请确认对应软件及脚本的许可证和使用条款。
