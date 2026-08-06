# Mini Shai-Hulud npm 供应链事件响应：一次维护者接手案例

> English version: [`mini-shai-hulud-npm-incident-response.md`](mini-shai-hulud-npm-incident-response.md)

本文记录了一次真实的 npm 供应链应急响应过程：Socket 将多个历史 `@lint-md` 版本列入 Mini Shai-Hulud 受影响包列表，而现维护者是在这些版本发布之后才接手项目。

本文重点不是逆向分析恶意载荷，而是说明怎样从“安全平台搜索到了我的包名”推进到基于证据的结论，避免安装可疑版本、错误归因、过度轮换全部密钥，或者把单个历史版本的问题扩大成整个项目都被入侵。

## 结论摘要

Socket 的受影响包搜索结果列出了以下历史版本：

| 包 | Socket 显示的版本 |
|---|---|
| `@lint-md/core` | `2.1.0`、`2.2.0` |
| `@lint-md/cli` | `2.1.0`、`2.2.0` |
| `@lint-md/parser` | `0.1.14`、`0.2.14` |

这些版本发布于 2026 年 5 月 19 日，与 Socket 描述的 Mini Shai-Hulud 恶意发包波次时间一致。现维护者于 2026 年 6 月初接手项目，晚于上述版本的发布时间。

调查得到的主要结论：

- 现维护者不是这些历史版本的发布者；
- 维护者最初实际安装的是 `@lint-md/cli@2.2.3`，它解析到 `@lint-md/core@2.2.1`，不是 Socket 列出的 `core@2.2.0`；
- 重新安装当前 CLI 后，依赖树变为 `@lint-md/cli@2.2.4 -> @lint-md/core@2.3.0`；
- 没有发现 Socket 列出的 `core`、`cli` 或 `parser` 版本曾在维护者机器上安装或执行的证据；
- 当前已知正常版本的 Registry 元数据中，没有发现 `preinstall`、`install` 或 `postinstall`；
- 对两个受影响的 parser 版本执行 `npm deprecate` 时返回 `No version found`，说明当时查询的 Registry 已经无法找到这些版本；
- 正确做法是精确到版本进行隔离、验证和公告，而不是直接声称整个 `@lint-md` 命名空间或 GitHub 源码仓库都被入侵。

## 为什么这个事件很容易判断错误

安全平台显示了自己的包名后，很容易立即得出一些看似合理、实际上证据不足的结论。

### 错误结论一：当前 GitHub 仓库被投毒了

npm Registry 上的 tarball 可以与 GitHub 仓库源码不同。攻击者如果取得发包权限，可以直接发布恶意版本，而 GitHub 源码仓库仍然保持正常。

### 错误结论二：当前维护者发布了恶意版本

必须先核对 npm 发布时间和项目接手时间。本案例中，可疑版本发布于 5 月 19 日，而现维护者 6 月初才接手。

### 错误结论三：安装过 CLI，就一定执行过受影响的 Core

必须查询实际安装的 CLI 版本、该版本的依赖范围以及最终依赖树，不能只看当前 `latest` 的依赖声明。

### 错误结论四：`npm audit` 没报错，所以不存在风险

`npm audit` 主要依赖已发布的漏洞和安全公告。新发现的恶意版本可能还没有进入传统漏洞数据库。

### 错误结论五：没有 `postinstall`，所以肯定安全

没有安装生命周期脚本只能降低一种自动执行风险。恶意代码还可能在包被导入、运行、构建或测试时执行。

### 错误结论六：`No version found` 说明 npm 官方删除了版本

它只能证明当前查询的 Registry 找不到该版本，不能证明是谁删除或处理了它。

因此，本次响应始终把以下四个问题分开：

1. 哪些精确版本被安全平台列为受影响？
2. 这些版本当前是否仍存在于 npm Registry？
3. 这些精确版本是否在本地或 CI 中执行过？
4. 如果执行过，当时哪些密钥处于可访问状态？

## 时间线重建

在归因和轮换密钥前，先建立时间线。

```text
2026-05-19
  Socket 记录 Mini Shai-Hulud 恶意发包波次。
  多个历史 @lint-md 版本出现在受影响包搜索结果中。

2026 年 6 月初
  现维护者接手项目维护。

接手之后
  维护者主要从源码仓库开发并发布新版本。
  npm 发包开启 2FA。

2026-08-06
  根据 Socket 结果检查 npm Registry、实际依赖树、缓存、脚本和密钥暴露路径。
```

时间线确定后，问题不再是：

> 当前维护者是否发布了恶意版本？

而变成：

> 当前维护者是否接手了含有恶意历史版本的包，以及这些历史版本是否进入过新的维护环境？

## 第一步：固定受影响版本范围

先记录安全平台明确列出的版本：

```text
@lint-md/core:   2.1.0、2.2.0
@lint-md/cli:    2.1.0、2.2.0
@lint-md/parser: 0.1.14、0.2.14
```

没有证据时，不把其他版本一起标记为恶意。

同一 npm scope 中可能同时存在：

- 被攻击者发布的恶意历史版本；
- 未受影响的早期版本；
- 事件后由新维护者发布的正常版本；
- 通过 `npm link` 或本地源码安装产生的链接版本。

因此，响应边界必须是 `package@version`，而不是只有 package name。

## 第二步：确认 Registry 和发布时间

任何修改操作前，先保存当前 Registry 状态。

```bash
npm config get registry

npm view @lint-md/core versions --json
npm view @lint-md/core time --json
npm view @lint-md/core dist-tags --json

npm view @lint-md/cli versions --json
npm view @lint-md/cli time --json
npm view @lint-md/cli dist-tags --json

npm view @lint-md/parser versions --json
npm view @lint-md/parser time --json
npm view @lint-md/parser dist-tags --json
```

如果可能使用了企业代理或镜像，应显式查询官方 Registry：

```bash
npm view "@lint-md/parser@0.1.14" version \
  --registry=https://registry.npmjs.org/
```

在执行 `npm deprecate`、修改 `dist-tag` 或移除 owner 之前，应先保存：

- 版本列表；
- 发布时间；
- 当前 `latest`；
- maintainers / owners；
- 每个受影响版本的 scripts、dependencies 和 dist 信息。

## 第三步：查询精确版本，而不是只看 latest

调查过程中曾出现一个看似矛盾的结果。

查询当前 CLI 依赖：

```bash
npm view @lint-md/cli dependencies
```

返回：

```text
@lint-md/core: ^2.3.0
```

但本地依赖树显示：

```bash
npm ls -g @lint-md/core
```

```text
@lint-md/cli@2.2.3
└── @lint-md/core@2.2.1
```

原因不是 npm 解析异常，而是两个命令查看的对象不同：

- `npm view @lint-md/cli dependencies` 查看当前默认版本，也就是当时的 latest；
- 本地安装的是历史版本 `@lint-md/cli@2.2.3`。

正确查询方式：

```bash
npm view @lint-md/cli@2.2.3 dependencies
```

结果是：

```text
@lint-md/core: ^2.2.1
```

这个依赖范围解析到 `2.2.1` 是正常的。

重新安装当前 CLI：

```bash
npm uninstall -g @lint-md/cli
npm install -g @lint-md/cli
npm ls -g @lint-md/core
```

依赖树变成：

```text
@lint-md/cli@2.2.4
└── @lint-md/core@2.3.0
```

### 可复用经验

调查历史安装时，不要只运行：

```bash
npm view <package> dependencies
```

应查询实际安装的父包版本：

```bash
npm view "<package>@<installed-version>" dependencies
```

## 第四步：区分 Registry 包和本地 link

全局依赖树还显示：

```text
@lint-md/core@2.3.0 -> /home/luo/devOps/lint-md
```

这是本地源码链接，不是从 npm Registry 下载的 tarball。

本地 link 可能让 `npm ls` 看起来出现重复依赖、自依赖或奇怪的版本层级。可以通过以下命令确认：

```bash
npm ls -g @lint-md/core --all
npm explain @lint-md/core
readlink -f "$(npm root -g)/@lint-md/core"
```

本地链接应该按本地源码和 lockfile 进行分析，不能直接视为安装过相同版本号的 Registry tarball。

## 第五步：检查直接依赖和传递依赖

维护者只直接安装过 CLI，因此必须检查 CLI 是否间接拉入了受影响版本。

```bash
npm ls -g @lint-md/cli --all
npm ls -g @lint-md/core --all
npm ls -g @lint-md/parser --all
```

在项目目录中继续检查：

```bash
npm ls @lint-md/core --all
npm ls @lint-md/parser --all
```

pnpm 项目使用：

```bash
pnpm why @lint-md/core
pnpm why @lint-md/parser
```

还应检查：

- `package-lock.json`、`pnpm-lock.yaml`；
- GitHub Actions 安装日志；
- 构建和发布日志；
- 是否使用过 `npm install -g`、`npx` 或临时 CI 环境。

本案例中，实际安装路径没有出现 Socket 列出的精确版本。

## 第六步：谨慎解释 npm cache

执行：

```bash
npm cache ls | grep lint-md
```

缓存中存在多个 `@lint-md` tarball 和 Registry 查询记录，但没有看到 Socket 列出的恶意版本。

这可以作为低暴露风险的支持证据，但不是决定性证据：

- 缓存中存在 tarball，不代表其中代码一定执行过；
- 缓存中不存在 tarball，也不代表从未安装，因为缓存可能被清理、迁移或过期；
- `security-advisory:` 开头的记录通常是安全公告元数据，不等于本机存在恶意程序。

## 第七步：在不安装包的情况下检查脚本

查询已安装的正常 Core 版本：

```bash
npm view @lint-md/core@2.2.1 scripts
```

返回的主要是开发和发布脚本，例如：

```text
lint
test
build
prepublishOnly
package-contract
```

没有发现：

```text
preinstall
install
postinstall
```

这降低了安装时自动执行恶意代码的可能性。

还需要正确理解 `prepublishOnly`：

- `prepublishOnly` 在维护者执行 `npm publish` 时运行；
- 它不是下游用户安装包时执行的脚本；
- `preinstall`、`install` 和 `postinstall` 才是安装路径中需要重点检查的生命周期脚本。

但“没有安装脚本”仍然不能作为完整安全证明。包被导入、执行 CLI、运行测试或构建时，也可能触发恶意代码。

## 第八步：只下载 tarball 做静态检查，不安装

调查可疑 npm 包时，不应运行：

```bash
npm install <suspicious-package>
```

安全做法是通过 `npm pack` 保存 tarball：

```bash
mkdir -p incident-artifacts/tarballs
cd incident-artifacts/tarballs

npm pack --ignore-scripts "@scope/package@1.2.3"
sha256sum ./*.tgz
tar -tzf ./*.tgz
```

如需解包，只能在隔离目录中把它当作不可信数据查看：

```bash
mkdir extracted
tar -xzf package-1.2.3.tgz -C extracted
find extracted -type f -print
```

不要执行：

- 包入口文件；
- tarball 中的 JavaScript 或 Shell 脚本；
- 测试或构建命令；
- tarball 自带的二进制文件。

本案例中，部分受影响版本已经无法从 Registry 获取，因此记录缺失状态比从第三方来源安装它们更安全。

## 第九步：精确处理 npm deprecate

维护者尝试弃用 Socket 列出的 parser 版本：

```bash
npm deprecate "@lint-md/parser@0.1.14" \
  "Security notice: affected by the Mini Shai-Hulud supply-chain incident."

npm deprecate "@lint-md/parser@0.2.14" \
  "Security notice: affected by the Mini Shai-Hulud supply-chain incident."
```

npm 返回：

```text
npm warn deprecate No version found for 0.1.14
npm warn deprecate No version found for 0.2.14
```

正确解释是：

> 当前查询的 Registry 已经找不到这些版本，因此无法更新其 deprecated 元数据。

这不能证明：

- 是 npm 官方删除的；
- 是 Socket 处理的；
- 是旧维护者删除的；
- 版本从未存在。

后续验证：

```bash
npm view @lint-md/parser versions --json
npm view @lint-md/parser@0.1.14 version
npm view @lint-md/parser@0.2.14 version
```

如果受影响版本仍存在，应该只弃用精确版本：

```bash
npm deprecate "@scope/package@1.2.3" \
  "Security notice: affected release. Upgrade to 1.2.5 or newer."
```

不要因为两个版本受影响而直接弃用整个包或整个 major 范围。

还需要注意：`npm deprecate` 只会在用户以后安装时显示警告，不会主动给所有历史用户发送邮件。因此仍需要发布 GitHub Security Advisory、Release 说明或置顶 Issue。

## 第十步：根据执行路径判断密钥风险

维护者有大量通过 GPG 加密管理的密钥，并周期性解锁使用。

GPG 加密降低了静态文件被直接读取的风险，但不能自动排除运行时暴露。需要逐项回答：

- 受影响包是否实际执行过？
- 当时密钥是否已解密到环境变量？
- 是否存在明文临时文件？
- `gpg-agent` 或其他 credential agent 是否处于解锁状态？
- 恶意进程是否能够读取环境、文件或调用 agent？
- 之后是否出现异常 npm 发包、GitHub 操作、云平台访问或部署行为？

本案例没有发现受影响版本在本地或 CI 执行的证据，因此没有必要无差别轮换所有密钥。

如果后续证明恶意版本执行时可以访问 npm token、GitHub token、云密钥、SSH 密钥或已解锁的 agent，则必须把对应凭据视为可能泄露并立即撤销或轮换。

## 本案例的处置方案

最终采用的响应步骤：

1. 保存 Socket 截图和精确受影响版本列表；
2. 保存 npm 版本列表、发布时间、owner 和 `dist-tag`；
3. 检查本地和 CI 中是否出现每个精确受影响版本；
4. 保持当前 CLI 和 Core 使用已知正常版本；
5. 仅对仍存在的受影响版本执行 `npm deprecate`；
6. 对无法找到的版本记录为“当前 Registry 不可用”，不猜测删除者；
7. 确认 npm 发包 2FA，检查 owner 和继承 token；
8. 移除不再需要或来源不明的发布凭据；
9. 发布包含精确受影响版本和升级版本的安全公告；
10. 保存完整事件报告，方便以后维护者和用户复核。

## 本次响应刻意没有做的事情

- 没有把整个 `@lint-md` scope 都标记为恶意；
- 没有在缺乏证据时声称 GitHub 仓库被入侵；
- 没有把 5 月发布的版本归因给 6 月才接手的维护者；
- 没有安装可疑版本来检查；
- 没有把 `npm audit` 无告警当作安全证明；
- 没有把“无 postinstall”当作最终结论；
- 没有在缺乏执行路径时轮换所有 GPG 管理的密钥；
- 没有声称 parser 版本一定由 npm 官方删除。

## 可复用命令清单

使用前替换包名和版本号。

```bash
# Registry
npm config get registry

# 当前包状态
npm view @scope/package version
npm view @scope/package versions --json
npm view @scope/package time --json
npm view @scope/package dist-tags --json
npm owner ls @scope/package

# 精确受影响版本元数据
npm view "@scope/package@1.2.3" version
npm view "@scope/package@1.2.3" scripts --json
npm view "@scope/package@1.2.3" dependencies --json
npm view "@scope/package@1.2.3" deprecated
npm view "@scope/package@1.2.3" dist --json

# 本地暴露检查
npm ls -g @scope/package --all
npm ls @scope/package --all
pnpm why @scope/package
npm cache ls | grep -F '@scope/package'

# 安全下载 tarball，不安装
npm pack --ignore-scripts "@scope/package@1.2.3"
sha256sum ./*.tgz
tar -tzf ./*.tgz

# 版本仍存在时进行精确弃用
npm deprecate "@scope/package@1.2.3" \
  "Security notice: affected release. Upgrade to 1.2.5 or newer."

# 验证默认安装版本
npm dist-tag ls @scope/package
npm view @scope/package version
```

本仓库的只读脚本可以自动收集大部分证据：

```bash
./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

需要下载 tarball 做静态检查时：

```bash
DOWNLOAD_TARBALLS=1 \
  ./scripts/triage-npm-package.sh @scope/package 1.2.3 1.2.4
```

## 主要经验

### 版本范围比包名范围更重要

供应链应急响应应从精确版本开始。没有证据时，不扩大到其他版本。

### 时间线可以避免错误归因

发布时间和维护权转移时间，可能完全改变事件假设。

### 实际依赖树比当前 Registry 元数据更重要

`npm view <package> dependencies` 默认查看当前版本。调查历史安装必须查询精确父包版本，并结合本地 `npm ls` 或 `pnpm why`。

### Registry 找不到版本和版本是否安全是两个问题

`No version found` 只能说明当前 Registry 无法找到版本，不能说明谁删除了它，也不能说明历史用户从未安装。

### 密钥轮换必须跟随实际执行暴露

关键不是包名是否出现在告警里，而是恶意代码是否真的运行，以及运行时某个具体密钥是否可访问。

## 参考资料

- [Socket：Mini Shai-Hulud 供应链攻击](https://socket.dev/supply-chain-attacks/mini-shai-hulud)
- [Socket：Mini Shai-Hulud npm 恶意发包波次](https://socket.dev/blog/antv-packages-compromised)
- [npm 文档：scripts 与生命周期事件](https://docs.npmjs.com/cli/using-npm/scripts/)
- [npm 文档：弃用 package 或精确版本](https://docs.npmjs.com/deprecating-and-undeprecating-packages-or-package-versions/)
- [npm Unpublish Policy](https://docs.npmjs.com/policies/unpublish/)

## 范围说明

本文记录的是维护者调查过程中能够获得的证据和响应方法。它不独立认证所有未列出版本都绝对安全，不识别历史版本的发布者或删除者，也不能替代安全平台对恶意载荷的专业分析。
