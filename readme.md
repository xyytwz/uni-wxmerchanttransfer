# uni-wxmerchanttransfer

> 仓库名 / 工程名为 `uni-wxmerchanttransfer`，但 **DCloud 插件 ID 仍为 `xyyt-wxmerchanttransfer`**：插件 ID 规范格式为「作者ID-插件英文名」，而作者ID 不得使用 `DCloud`、`uni` 等关键字（见官方发布规范）。因此插件目录、`package.json` 的 `id`、鸿蒙模块名 `@uni_modules/xyyt-wxmerchanttransfer` 与页面导入路径均保持原样，请勿按仓库名改写。

uni-app **鸿蒙端（HarmonyOS NEXT）微信商家转账用户确认收款** UTS 插件 + demo 工程。

补位官方 `uni-requestMerchantTransfer` 缺失的 HarmonyOS 实现（该官方插件至今只有 Android/iOS，`arkts: false`）：调起微信确认收款页面（`requestMerchantTransfer`），并回传用户确认结果（`success` / `fail` / `cancel`）。调起字段与官方 API 完全一致，可直接作为鸿蒙分支替换使用。

> 关键机制：插件加载时用官方 `UTSHarmony.onAppAbilityCreate` / `onAppAbilityNewWant`（版本门槛：`@dcloudio/uni-app-runtime` 内 `UTSHarmony.d.ts` 标注 `harmony.uniUtsPlugin: "4.31"`，即 uni-app 鸿蒙 UTS 插件 ≥ 4.31）监听宿主 `EntryAbility` 生命周期，**自行接管微信回跳的 `Want`**，因此宿主无需修改任何原生代码。原理：HBuilderX 生成的鸿蒙 `EntryAbility` 继承运行时 `UniEntryAbility`，其 `onCreate` / `onNewWant` 会向 `appAbilityEmitter` 发出 `create` / `newWant` 事件，而 `UTSHarmony.onAppAbility*` 订阅的正是这两个事件（注：鸿蒙平台只有本地打包，不存在云打包）。但宿主仍**必须在 `module.json5` 配齐两项**：`querySchemes: ["weixin"]` 管拉起、`wxentity.action.open` 管回跳，缺一不可（见下节）。

- 插件本体与完整集成文档：[`src/uni_modules/xyyt-wxmerchanttransfer`](src/uni_modules/xyyt-wxmerchanttransfer)（上传 DCloud 插件市场时打包此目录）
- 插件市场：即将上架 DCloud 插件市场（ext.dcloud.net.cn），上架后在此回填链接
- 配套博文：即将发布于掘金 / 博客园，发布后在此回填链接

## 仓库结构

| 路径 | 说明 |
|---|---|
| `src/uni_modules/xyyt-wxmerchanttransfer/` | **插件本体（唯一权威源）**：`package.json` / `readme.md` / `changelog.md` / `utssdk/` / `native-integration/` |
| `src/pages/index/index.vue` | demo 页：参数输入 → 调起 → 一次性回调与轮询结果展示 |
| `blog/` | 配套技术博文源稿（可行性分析 / 方案设计 / 踩坑记录） |
| `scripts/check-sensitive.ps1` | 发布前脱敏自检（见下方「发布前检查」） |
| 根 `package.json` / `vite.config.ts` | uni-app cli 工程（vue3）——本仓库同时就是插件的 demo 工程 |

## 跑 demo

```bash
npm install
npm run dev:app-harmony     # 或 npx uni build -p app-harmony，再导入 HBuilderX / DevEco Studio
```

## 宿主配置：module.json5 两项，缺一不可

微信的「拉起」与「回跳」分属两条通道，各需一个声明。**注意两项在 JSON 里的层级不同**：`querySchemes` 在 `module` 节点下，`actions` 必须嵌在 `abilities[].skills[]` 内。

```json5
{
  "module": {
    "querySchemes": ["weixin"],
    "abilities": [
      {
        "name": "EntryAbility",
        "skills": [
          {
            "entities": ["entity.system.home"],
            "actions": ["action.system.home", "wxentity.action.open"]
          }
        ]
      }
    ]
  }
}
```

| 缺哪一项 | 现象 |
|---|---|
| `querySchemes` | 报「未安装微信或微信版本过低」（实为 `canOpenLink` 抛 17700056 被 SDK 吞成 false） |
| `wxentity.action.open` | **拉起一切正常**，但确认结果永远取不到（回调不触发、轮询恒为 `null`） |

两项均编译进 HAP，**改完必须重新构建并安装**，WGT 热更新与替换 `www` 无效；建议解包 HAP 确认已生效。工程形态上的落地差异（HBuilderX 工程走 `harmony-configs/` 整体覆盖，cli / 自维护工程直接改源文件并注意构建脚本是否会重新生成）见插件 [`readme.md` 2.2`](src/uni_modules/xyyt-wxmerchanttransfer/readme.md)。

**不需要改 `EntryAbility`**：Want 接管已由插件内部钩子完成。

冷启动回跳兜底（App 被系统回收后从微信返回，此时插件尚无 `WXApi` 实例）——在 `App.vue` 的 `onLaunch` 里加一行：

```ts
// #ifdef APP-HARMONY
import { setMerchantTransferAppId } from '@/uni_modules/xyyt-wxmerchanttransfer'
setMerchantTransferAppId('wxYourAppId')
// #endif
```

### 可选：自维护原生工程手工转发

离线打包 / 原生权威工程若希望在原生层显式控制分发时机，可继续用 `handleWeChatWant`（与自动接管二选一，勿叠加）：

```ets
import { handleWeChatWant } from '@uni_modules/xyyt-wxmerchanttransfer'

onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  handleWeChatWant(want)
  super.onCreate(want, launchParam)
}

onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  handleWeChatWant(want)
  super.onNewWant(want, launchParam)
}
```

完整示例见 [`native-integration/EntryAbility.example.ets`](src/uni_modules/xyyt-wxmerchanttransfer/native-integration/EntryAbility.example.ets)。原生工程内引用插件产物用模块名 `@uni_modules/<插件id>`，不要用 uts 源码相对路径。

## 业务调用

```ts
// #ifdef APP-HARMONY
import { requestMerchantTransfer, onMerchantTransferResult } from '@/uni_modules/xyyt-wxmerchanttransfer'
// #endif

// 一次性结果回调（触发后自动注销）
onMerchantTransferResult((res) => {
  console.log(res.result, res.errMsg) // success | fail | cancel
})

requestMerchantTransfer({
  mchId: '1900000109',   // 示例商户号（微信官方文档样例），换成你的
  appId: 'wxYourAppId',  // 你的微信开放平台 AppID
  package: 'xxxxxxxx',   // 后端转账单据应答中的 package_info
  success: () => { /* 仅代表页面拉起成功 */ },
  fail: (res) => { /* 未装微信 / 版本过低 / 参数缺失 / 发送失败 */ }
})
```

## 必读事项

1. **`success` 语义**：微信官方定义回调 `success` 仅表示“确认收款页面展示成功”，**不代表用户已确认、更不代表资金到账**；业务侧请以刷新后的订单/列表接口为准。
2. **HBuilderX 工程须保留一条页面静态 import**：UTS 插件只有被前端静态引用时才纳入编译范围，而钩子是在插件模块加载时安装的——插件没进编译范围等于钩子不存在，调起能发起但确认结果永远回不来。
3. **插件升级需重打整包**：插件代码被编为 ArkTS 进 HAP，不在 JS 层，WGT 热更新覆盖不了；但接入已不需要宿主改原生代码。
4. **依赖**：`@tencent/wechat_open_sdk@1.0.23` 由插件 `utssdk/app-harmony/config.json` 声明，编译鸿蒙时自动进 ohpm；与微信登录插件（uni-oauth-weixin）共存时同依赖自动去重，版本冲突可在根 `oh-package.json5` 的 `overrides` 统一。
5. **微信客户端版本**：需 ≥ 8.0.11.34，低于此版本无法拉起确认收款页。

## 验证状态

| 项 | 结果 |
|---|---|
| `uni build -p app-harmony` | ✅ 通过；cli 阶段即完成 `uts → ets` 编译（ArkTS 语法有效性同步验证），并自动生成插件注册代码 |
| H5 交叉构建与隔离 | ✅ 通过；插件代码不出现在非鸿蒙端产物 |
| 真机链路（原生直连 / 宿主转发路径） | ✅ HarmonyOS NEXT + 微信 8.0.x：点领取 → 拉起微信确认收款 → 确认后回跳 → 结果回调 → 列表刷新（在主工程自定义原生壳内以原生代码直连验证，等价于 `handleWeChatWant` 路径） |
| `UTSHarmony` 自动接管（本版本主推路径） | ✅ 2026-11-18 独立插件工程（uni-app cli + demo）真机闭环：宿主原生零改动，调起确认收款页 → 微信侧取消回跳 → `onMerchantTransferResult` 与 `getLastMerchantTransferResult()` 均返回 `{"result":"cancel"}`（走 `onAppAbilityNewWant`） |
| `onAppAbilityCreate` 冷启动回跳 / 暂存补投 | ⚠️ 仅有工程与编译层证据，**尚无真机结论** |

## 发布前检查（脱敏）

HBuilderX 会把你本机的鸿蒙签名材料静默写进 `src/manifest.json`：`app-harmony.distribute.bundleName` 改成真实包名、`appid` 填上真实 DCloud 标识，并新增一整块 `signingConfigs`（`certpath` / `profile` / `storeFile` / `keyPassword` / `storePassword`，全是本机绝对路径）。它看起来只是普通配置改动，特别容易被顺手提交。

发布 / 推代码前跑一次：

```bash
npm run check:sensitive          # 扫工作区已跟踪文件
npm run check:sensitive:staged   # 扫 git 索引（可挂 pre-commit）
npm run check:sensitive:selftest # 断言每条规则都能命中自己的样本（改过规则就跑一次）
```

准备上传插件市场时，直接扫将要压缩的那个目录（未跟踪、被 gitignore 的文件也一起扫）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive.ps1 -Paths src/uni_modules/xyyt-wxmerchanttransfer
```

`-Paths` 用逗号分隔多项；任一路径不存在时脚本以退出码 2 直接报错，**不会**因为“没扫到东西”而假装通过——这条是踩坑后加的：git grep 拿到一个不存在的 pathspec 时返回 1（无匹配），旧版本据此报过 clean。

规则只匹配**形态**（签名配置键名、证书目录、`__UNI__xxxxxxxx`、`wx` + 16 位十六进制、绝对用户目录、长 base64 串），脚本本身不含任何公司值。你公司自己的包名前缀 / 商户号 / 微信 AppID 请写进一个不入库的本地清单，用 `-PatternsFile <path>` 传进去：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-sensitive.ps1 -PatternsFile ../my-deny.txt
```

命中时先还原被工具改写的文件，再复扫：

```bash
git restore src/manifest.json
npm run check:sensitive
```

另外：

- 上传 DCloud 插件市场只打包 `src/uni_modules/xyyt-wxmerchanttransfer`，不要压缩整个仓库。
- 运行时日志同样属于“脱敏”范围：`index.uts` 组装的 query 里含 `package_info`（一次性转账单据令牌）与 `openId`（用户标识），已被降级为只打印可选字段的键名，不打印取值。自行加日志时请沿用这条约束。
- `dist/` 与 `unpackage/` 虽已 gitignore，但里面的 hvigor 构建日志会记录本机用户名与历史签名路径，打包前建议直接删掉（下次构建自动重建）。
- 想让 `src/manifest.json` 从此不再进提交视野：`git update-index --skip-worktree src/manifest.json`（仅本地生效；恢复跟踪用 `--no-skip-worktree`）。

## 许可

本仓库暂未附带 LICENSE 文件；DCloud 插件市场发布为免费插件（含源码）。如需明确为 MIT / Apache-2.0 等开源许可，请自行添加 LICENSE 文件。
