# xyyt-wxmerchanttransfer

鸿蒙（HarmonyOS NEXT）端**微信商家转账用户确认收款**插件：调起微信确认收款页面（`requestMerchantTransfer`），并回传用户确认结果。

官方插件 `uni-requestMerchantTransfer` 目前只实现了 Android/iOS（鸿蒙端为 `-`），本插件补位鸿蒙实现；**调起字段与官方 API 保持一致**，可直接作为鸿蒙分支替换使用。

> 已验证环境：uni-app（vue3）+ 自定义原生壳工程（DevEco Studio）+ `@tencent/wechat_open_sdk@1.0.23` + HarmonyOS NEXT 真机 + 微信客户端 8.0.x。
>
> 配套博文《补上缺失的拼图：为 uni-app 鸿蒙端实现微信“商家转账确认收款”插件》（可行性分析 / 宿主转发方案 / 踩坑记录）：掘金 `https://juejin.cn/post/TODO` · 博客园 `https://www.cnblogs.com/TODO`（发布后回填）

---

## 一、功能与平台

| 能力 | 说明 |
|---|---|
| `requestMerchantTransfer(options)` | 调起微信确认收款页面（businessType=`requestMerchantTransfer`） |
| `onMerchantTransferResult(cb)` | 【鸿蒙增强】一次性回调用户确认结果（`success`/`fail`/`cancel`） |
| `getLastMerchantTransferResult()` | 【鸿蒙增强】轮询式读取最近一次确认结果 |
| `clearMerchantTransferResult()` | 清除结果缓存 |
| `offMerchantTransferResult()` | 注销未触发的结果回调 |
| `handleWeChatWant(want, appId?)` | 【宿主集成】转发微信回跳 Want 给插件 |

| 平台 | 支持 |
|---|---|
| HarmonyOS NEXT（app-harmony） | ✅ |
| Android / iOS / H5 / 小程序 | ❌（请继续使用官方 `uni-requestMerchantTransfer` 或 `wx.requestMerchantTransfer`） |

环境要求：

- HBuilderX ≥ 4.23（鸿蒙 UTS 插件编译），uni-app vue3 工程
- 微信客户端 ≥ 8.0.11.34（低于此版本无法拉起确认收款页面）
- 微信开放平台已为宿主 App 配置鸿蒙平台（Bundle ID + appIdentifier），AppID 与调起参数 `appId` 一致

---

## 二、集成步骤

### 2.1 安装插件

将 `xyyt-wxmerchanttransfer` 目录复制到工程 `src/uni_modules/` 下（HBuilderX 导入插件同理）。插件会自带依赖声明（`@tencent/wechat_open_sdk@1.0.23`，见 `utssdk/app-harmony/config.json`），编译鸿蒙时自动加入 ohpm 依赖。

### 2.2 宿主 module.json5 配置 querySchemes（必须）

微信回跳宿主依赖 scheme 白名单。在你的鸿蒙原生工程 `entry/src/main/module.json5` 的 `module` 节点中配置：

```json5
{
  "module": {
    // ...
    "querySchemes": ["weixin"],
    "actions": ["action.system.home", "wxentity.action.open"]
  }
}
```

> uni-app HBuilderX 默认生成的鸿蒙壳工程同样如此：找到生成的 `entry/src/main/module.json5` 添加（或通过 harmony-configs 覆盖）。

### 2.3 宿主 EntryAbility 转发微信回跳 Want（必须）

**鸿蒙 UTS 插件没有应用生命周期代理**（官方 UTS 文档：HookProxy 仅 iOS/Android，鸿蒙平台"不涉及"），因此微信回跳的 Want 必须由宿主 `EntryAbility` 转发给插件——这是本插件区别于 Android/iOS 插件的唯一额外集成步骤。

在 `entry/src/main/ets/entryability/EntryAbility.ets` 中：

```ets
// 1) 顶部导入（插件编译产物模块名 = 插件 id 全小写）
import { handleWeChatWant } from '@uni_modules/xyyt-wxmerchanttransfer'
// 若路径报错，以鸿蒙工程内实际生成的产物为准
// （可在 entry/src/main/ets/uni_modules/ 或 oh_modules 内搜索 handleWeChatWant 确认）

// 2) onCreate / onNewWant 中转发
onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  handleWeChatWant(want);
  // ...原有逻辑
}

onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  handleWeChatWant(want);
  // ...原有逻辑
}
```

完整示例见插件内 `native-integration/EntryAbility.example.ets`。

**与微信登录（uni-oauth-weixin）共存**：二者各自调用 `WXApi.handleWant(want, 各自的 handler)`，各自只处理认识的 `resp` 类型（登录处理 `SendAuth.Resp`，本插件处理 `OpenBusinessViewResp`），互不冲突。若宿主已集成微信登录，仅需在本插件再补一次 `handleWeChatWant(want)` 调用。

### 2.4 页面调用

```vue
<script setup lang="ts">
// #ifdef APP-HARMONY
import {
  requestMerchantTransfer,
  onMerchantTransferResult,
  getLastMerchantTransferResult
} from '@/uni_modules/xyyt-wxmerchanttransfer'
// #endif

// 1) 先注册结果回调（一次性，触发后自动注销）
// #ifdef APP-HARMONY
onMerchantTransferResult((res) => {
  // res.result: 'success' | 'fail' | 'cancel'
  // res.errMsg: 微信回传的 extMsg 原始 JSON，如 {"result":"success"}
  if (res.result === 'success') {
    uni.showToast({ title: '请留意到账结果', icon: 'none' })
  }
})
// #endif

// 2) 调起确认收款（package 为后端"转账单据"应答中的 package_info，
//    仅当单据状态为 WAIT_USER_CONFIRM 时返回）
function receive() {
  // #ifdef APP-HARMONY
  requestMerchantTransfer({
    mchId: '1900000109',   // 示例商户号（微信官方文档样例），换成你的商户号
    appId: 'wxYourAppId',  // 换成你的微信开放平台 AppID
    package: 'xxxxxxxx',   // 后端转账单据应答中的 package_info
    success: (res) => {
      // 仅代表页面拉起成功
      console.log('拉起成功', res.errMsg)
    },
    fail: (res) => {
      uni.showToast({ title: res.errMsg, icon: 'none' })
    }
  })
  // #endif
}
// #endif
</script>
```

不想用回调也可以轮询读取：

```ts
// #ifdef APP-HARMONY
const timer = setInterval(() => {
  const r = getLastMerchantTransferResult()
  if (r != null) {
    clearInterval(timer)
    // 处理 r.result ...
  }
}, 1000)
// #endif
```

---

## 三、API

### requestMerchantTransfer(options)

调起微信确认收款页面。字段与官方 `uni.requestMerchantTransfer` 一致：

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| mchId | string | 是 | 微信支付商户号 |
| appId | string | 是 | 微信开放平台移动应用 AppID |
| package | string | 是 | 转账单据应答的 `package_info`（状态 `WAIT_USER_CONFIRM` 时返回） |
| openId | string | 否 | 用户在微信开放平台 appid 下的唯一标识 |
| subAppId | string | 否 | 服务商模式：子商户 appid |
| subMchId | string | 否 | 服务商模式：子商户号 |
| success | callback | 否 | 调起成功（页面拉起意图已发出） |
| fail | callback | 否 | 调起失败（未安装微信/版本过低/参数缺失/发送失败） |
| complete | callback | 否 | 结束回调 |

回调结果：`{ errMsg: string }`，`success` 时为 `requestMerchantTransfer:ok`。

### onMerchantTransferResult(callback)【鸿蒙增强】

注册**一次性**用户确认结果回调；微信回跳后触发并自动注销。

| 字段 | 说明 |
|---|---|
| res.result | `success`（微信确认收款**页面展示成功**，不代表确认成功，到账以订单/列表接口为准）\| `fail` \| `cancel` |
| res.errMsg | 微信回传 `extMsg` 原始 JSON 字符串，如 `{"result":"success"}` |

### getLastMerchantTransferResult() / clearMerchantTransferResult()

轮询式读取/清除最近一次结果，用法见上文。

### handleWeChatWant(want, appId?)【宿主集成】

把微信回跳的 Want 交给插件分发；返回 `false` 表示插件未处理（如尚未建立 WXApi）。与宿主其他微信能力共存，见 2.3。

---

## 四、注意事项

1. **result 语义**：微信官方定义回调 `success` 仅表示"确认收款页面展示成功"，不代表用户已确认或资金到账；业务侧请以刷新后的订单/列表接口为准。
2. **原生改动必须整包**：本插件产物在鸿蒙原生层（含 EntryAbility 集成代码），WGT 热更新覆盖不了，升级需重新打 HAP 整包。
3. **重复调起**：`onMerchantTransferResult` 为一次性回调；同一时刻仅保留最后一次注册。重复调起前建议先处理上一次结果（或改用轮询 API）。
4. **依赖冲突**：若宿主同时集成微信登录插件（uni-oauth-weixin），其传递依赖同为 `@tencent/wechat_open_sdk`，ohpm 自动去重，无需处理；若出现版本不一致，可在鸿蒙工程根 `oh-package.json5` 的 `overrides` 中统一版本。
5. **服务商模式**：传 `subAppId`/`subMchId` 时 query 由微信侧校验，`mchId` 传服务商商户号。
6. **uni-app x**：插件声明兼容 uni-app x（harmony），但已在 uni-app（vue3）真机验证；uni-app x 下请以实际编译结果为准。
7. **HBuilderX 工程须保留一条页面静态 import**：UTS 插件只有在被前端静态引用时才会纳入编译范围。若只在原生 `EntryAbility` 引用 `handleWeChatWant`、页面侧无任何 import，HBuilderX 不会编译 `utssdk/app-harmony/index.uts`，运行时 `uni.requireUTSPlugin` 返回 undefined。请在任一 `#ifdef APP-HARMONY` 页面保留 `import ... from '@/uni_modules/xyyt-wxmerchanttransfer'`（demo 页即示例）。改动插件引用关系后，需先删除工程 `dist/`（HBuilderX 工程为 `unpackage/`）再重新运行，否则会复用旧的“未被引用”判定。

---

## 五、Demo

仓库 `demo-harmony-transfer/` 为 uni-app cli 工程（vue3），`src/pages/index/index.vue` 演示完整流程（参数输入 → 调起 → 结果回调与轮询展示）。真机验证需按第二节完成原生工程集成（querySchemes + EntryAbility 转发）。

## 六、已知限制

- 仅鸿蒙端生效；Android/iOS 请用官方插件（本插件不重复实现）。
- 调起依赖宿主集成 `handleWeChatWant`；未集成时调起可发起但收不到确认结果回调（`getLastMerchantTransferResult` 亦无结果），页面可据此提示。
