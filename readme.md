# uni-wxmerchanttransfer

> 仓库名 / 工程名为 `uni-wxmerchanttransfer`，但 **DCloud 插件 ID 仍为 `xyyt-wxmerchanttransfer`**：插件 ID 规范格式为「作者ID-插件英文名」，而作者ID 不得使用 `DCloud`、`uni` 等关键字（见官方发布规范）。因此插件目录、`package.json` 的 `id`、鸿蒙模块名 `@uni_modules/xyyt-wxmerchanttransfer` 与页面导入路径均保持原样，请勿按仓库名改写。

uni-app **鸿蒙端（HarmonyOS NEXT）微信商家转账用户确认收款** UTS 插件 + demo 工程。

补位官方 `uni-requestMerchantTransfer` 缺失的 HarmonyOS 实现（该官方插件至今只有 Android/iOS，`arkts: false`）：调起微信确认收款页面（`requestMerchantTransfer`），并回传用户确认结果（`success` / `fail` / `cancel`）。调起字段与官方 API 完全一致，可直接作为鸿蒙分支替换使用。

> 关键机制：插件加载时用官方 `UTSHarmony.onAppAbilityCreate` / `onAppAbilityNewWant`（兼容性标注：uni-app HarmonyOS UTS 插件 ≥ 4.31）监听宿主 `EntryAbility` 生命周期，**自行接管微信回跳的 `Want`**，因此宿主无需修改任何原生代码。原理：HBuilderX 生成的鸿蒙 `EntryAbility` 继承运行时 `UniEntryAbility`，其 `onCreate` / `onNewWant` 会向 `appAbilityEmitter` 发出 `create` / `newWant` 事件，而 `UTSHarmony.onAppAbility*` 订阅的正是这两个事件（注：鸿蒙平台只有本地打包，不存在云打包）。唯一必需的宿主配置是 `module.json5` 的 `querySchemes: ["weixin"]`。

- 插件本体与完整集成文档：[`src/uni_modules/xyyt-wxmerchanttransfer`](src/uni_modules/xyyt-wxmerchanttransfer)（上传 DCloud 插件市场时打包此目录）
- 插件市场：即将上架 DCloud 插件市场（ext.dcloud.net.cn），上架后在此回填链接
- 配套博文：即将发布于掘金 / 博客园，发布后在此回填链接

## 仓库结构

| 路径 | 说明 |
|---|---|
| `src/uni_modules/xyyt-wxmerchanttransfer/` | **插件本体（唯一权威源）**：`package.json` / `readme.md` / `changelog.md` / `utssdk/` / `native-integration/` |
| `src/pages/index/index.vue` | demo 页：参数输入 → 调起 → 一次性回调与轮询结果展示 |
| `blog/` | 配套技术博文源稿（可行性分析 / 方案设计 / 踩坑记录） |
| 根 `package.json` / `vite.config.ts` | uni-app cli 工程（vue3）——本仓库同时就是插件的 demo 工程 |

## 跑 demo

```bash
npm install
npm run dev:app-harmony     # 或 npx uni build -p app-harmony，再导入 HBuilderX / DevEco Studio
```

## 宿主配置：只有一项

`entry/src/main/module.json5` 的 `module` 节点内加 scheme 白名单（微信回跳宿主的前提）：

```json5
{
  "module": {
    "querySchemes": ["weixin"],
    "actions": ["action.system.home", "wxentity.action.open"]
  }
}
```

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
| `UTSHarmony` 自动接管（本版本主推路径） | ⚠️ 编译层已确认：生成的 ArkTS 正确 `import { UTSHarmony } from "@dcloudio/uni-app-runtime"` 并调用两个钩子、顶层完成安装；**HBuilderX + 真机验证待完成** |

## 许可

本仓库暂未附带 LICENSE 文件；DCloud 插件市场发布为免费插件（含源码）。如需明确为 MIT / Apache-2.0 等开源许可，请自行添加 LICENSE 文件。
