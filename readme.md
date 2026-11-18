# xyyt-wxmerchanttransfer

uni-app **鸿蒙端（HarmonyOS NEXT）微信商家转账用户确认收款** UTS 插件 + demo 工程。

补位官方 `uni-requestMerchantTransfer` 缺失的 HarmonyOS 实现（该官方插件至今只有 Android/iOS，`arkts: false`）：调起微信确认收款页面（`requestMerchantTransfer`），并回传用户确认结果（`success` / `fail` / `cancel`）。调起字段与官方 API 完全一致，可直接作为鸿蒙分支替换使用。

> 为什么官方一直没做：鸿蒙 UTS 插件**没有应用生命周期代理**（官方 HookProxy 机制仅 iOS / Android，鸿蒙平台文档明确“不涉及”），微信回跳的 `Want` 插件自身收不到，回调链路无法在插件内闭环。因此本插件要求宿主 `EntryAbility` 转发 Want——这是唯一需要改原生的集成点。

- 插件本体与完整集成文档：[`src/uni_modules/xyyt-wxmerchanttransfer`](src/uni_modules/xyyt-wxmerchanttransfer)（上传 DCloud 插件市场时打包此目录）
- 插件市场：`https://ext.dcloud.net.cn/plugin?id=TODO`（上架后回填）
- 配套博文：掘金 `https://juejin.cn/post/TODO` · 博客园 `https://www.cnblogs.com/TODO`（发布后回填）

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

## 真机验证与业务接入：必做的两步原生集成

HBuilderX 默认壳做不到，需自定义鸿蒙原生工程（或已接入的宿主工程）：

1. `entry/src/main/module.json5`：`"querySchemes": ["weixin"]`
2. `EntryAbility` 的 `onCreate` / `onNewWant` 转发 Want：

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
2. **HBuilderX 工程须保留一条页面静态 import**：UTS 插件只有被前端静态引用时才纳入编译范围。只在原生侧引用 `handleWeChatWant`、页面零 import 时，运行时 `uni.requireUTSPlugin` 会返回 undefined。
3. **原生改动必须整包**：升级需重新打 HAP 整包，WGT 热更新覆盖不了原生层。
4. **依赖**：`@tencent/wechat_open_sdk@1.0.23` 由插件 `utssdk/app-harmony/config.json` 声明，编译鸿蒙时自动进 ohpm；与微信登录插件（uni-oauth-weixin）共存时同依赖自动去重，版本冲突可在根 `oh-package.json5` 的 `overrides` 统一。
5. **微信客户端版本**：需 ≥ 8.0.11.34，低于此版本无法拉起确认收款页。

## 验证状态

| 项 | 结果 |
|---|---|
| `uni build -p app-harmony` | ✅ 通过；cli 阶段即完成 `uts → ets` 编译（ArkTS 语法有效性同步验证），并自动生成插件注册代码 |
| H5 交叉构建与隔离 | ✅ 通过；插件代码不出现在非鸿蒙端产物 |
| 真机链路 | ✅ HarmonyOS NEXT + 微信 8.0.x：点领取 → 拉起微信确认收款 → 确认后回跳 → 结果回调 → 列表刷新 |

## 许可

本仓库暂未附带 LICENSE 文件；DCloud 插件市场发布为免费插件（含源码）。如需明确为 MIT / Apache-2.0 等开源许可，请自行添加 LICENSE 文件。
