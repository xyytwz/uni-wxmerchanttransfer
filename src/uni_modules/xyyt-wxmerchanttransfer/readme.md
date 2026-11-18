# xyyt-wxmerchanttransfer

鸿蒙（HarmonyOS NEXT）端**微信商家转账用户确认收款**插件：调起微信确认收款页面（`requestMerchantTransfer`），并回传用户确认结果。

官方插件 `uni-requestMerchantTransfer` 目前只实现了 Android/iOS（鸿蒙端为 `-`），本插件补位鸿蒙实现；**调起字段与官方 API 保持一致**，可直接作为鸿蒙分支替换使用。

微信回跳的 `Want` 由插件内部通过 `UTSHarmony` 生命周期钩子自动接管，**宿主无需修改任何原生代码**，但必须在 `module.json5` 声明**两项**配置（`querySchemes` + `wxentity.action.open`，缺一不可，见 2.2）。

原理：HBuilderX 生成的鸿蒙 `EntryAbility` 继承运行时 `UniEntryAbility`，其 `onCreate` / `onNewWant` 内部会向 `appAbilityEmitter` 发出 `create` / `newWant` 事件，而 `UTSHarmony.onAppAbilityCreate` / `onAppAbilityNewWant` 订阅的正是这两个事件，因此插件必然能收到回跳 Want。注意鸿蒙平台只有「发行 → App-Harmony-本地打包」，**不存在云打包**。

> 已验证环境：uni-app（vue3）+ 自定义原生壳工程（DevEco Studio）+ `@tencent/wechat_open_sdk@1.0.23` + HarmonyOS NEXT 真机 + 微信客户端 8.0.x。
>
> 2026-11-18 已在独立 uni-app cli 工程真机跑通全链路：调起确认收款页 → 用户在微信侧取消回跳 → 宿主原生零改动、插件 `UTSHarmony` 钩子接管成功 → `onMerchantTransferResult` 与 `getLastMerchantTransferResult()` 均返回 `{"result":"cancel"}`。

---

## 一、功能与平台

| 能力 | 说明 |
|---|---|
| `requestMerchantTransfer(options)` | 调起微信确认收款页面（businessType=`requestMerchantTransfer`） |
| `onMerchantTransferResult(cb)` | 【鸿蒙增强】一次性回调用户确认结果（`success`/`fail`/`cancel`） |
| `getLastMerchantTransferResult()` | 【鸿蒙增强】轮询式读取最近一次确认结果 |
| `clearMerchantTransferResult()` | 清除结果缓存 |
| `offMerchantTransferResult()` | 注销未触发的结果回调 |
| `handleWeChatWant(want, appId?)` | 【可选】自维护原生工程时手工转发 Want（常规接入由插件自动完成） |
| `setMerchantTransferAppId(appId)` | 【冷启动兜底】预配 appId，使 `onCreate` 回跳的 Want 也能正常分发 |

| 平台 | 支持 |
|---|---|
| HarmonyOS NEXT（app-harmony） | ✅ |
| Android / iOS / H5 / 小程序 | ❌（请继续使用官方 `uni-requestMerchantTransfer` 或 `wx.requestMerchantTransfer`） |

环境要求：

- **uni-app 编译工具链 / HBuilderX ≥ 4.31**：插件依赖 `UTSHarmony.onAppAbilityCreate` / `onAppAbilityNewWant`，其版本门槛来自 `@dcloudio/uni-app-runtime` 包内 `src/main/ets/uni-mp-sdk/types/UTSHarmony.d.ts` 的 `@uniPlatform` 标注 `harmony: { uniUtsPlugin: "4.31", uniVer: "4.31" }`（即 uni-app 而非仅 uni-app x 的鸿蒙 UTS 插件自 4.31 起支持）。低于此版本钩子装不上，表现为「调起正常、确认结果永远取不到」。
- uni-app vue3 工程
- 微信客户端 ≥ 8.0.11.34（低于此版本无法拉起确认收款页面）
- 微信开放平台已为宿主 App 配置鸿蒙平台（Bundle ID + appIdentifier），AppID 与调起参数 `appId` 一致

---

## 二、集成步骤

### 2.1 安装插件

将 `xyyt-wxmerchanttransfer` 目录复制到工程 `src/uni_modules/` 下（从插件市场导入同理）。插件依赖声明在 `utssdk/app-harmony/config.json`（`@tencent/wechat_open_sdk@1.0.23`）。

依赖落地方式分两种，请注意区分：

- **HBuilderX 工程（运行到鸿蒙 / 本地打包）**：工具链会把 UTS 插件编成独立模块，并自动写入 `build-profile.json5` 的 modules、`oh-package.json5` 依赖与插件注册代码，无需手工处理。
- **已有自己的鸿蒙原生权威工程（离线打包 / 手工维护工程）**：`uni build -p app-harmony` 只产出 `dist/build/app-harmony`，**不会**替你修改工程配置。需自行完成四步：
  1. `ohpm install @tencent/wechat_open_sdk@1.0.23`；
  2. 根 `build-profile.json5` 的 `modules` 注册插件模块（`name` 须与模块自身 `src/main/module.json5` 的 `name` 完全一致，否则编译失败）；
  3. `entry/oh-package.json5` 加入本地模块依赖（形如 `"@uni_modules/xyyt-wxmerchanttransfer": "file:../xyyt_wxmerchanttransfer"`）；
  4. 在**参与 ArkTS 编译**的 `entry/src/main/ets/uni_modules/index.generated.ets` 补 `import` 与 `uni.registerUTSPlugin`（`www` 下的同名文件只是资源，不参与编译）。缺这一步时运行时 `uni.requireUTSPlugin` 返回 undefined。

### 2.2 宿主 module.json5 配置（必须两项，缺一不可）

微信的「拉起」和「回跳」是两条独立通道，各自需要一个声明。**只配一项时故障现象完全不同，且第二项缺失不会有任何报错提示**：

| 配置项 | 位置 | 作用 | 缺失时的表现 |
|---|---|---|---|
| `querySchemes: ["weixin"]` | `module` 节点 | 允许 `bundleManager.canOpenLink("weixin://")` 查询 | `@tencent/wechat_open_sdk` 的 `isWXAppInstalled()` 抛 BusinessError **17700056** 并被内部吞成 `false`（设备其实装了微信）。插件会自己再调一次 `canOpenLink` 分流成因，此时 `fail` 回的是「宿主 querySchemes 未配置」并直接给出修改位置，不会误导用户去装微信 |
| `actions` 含 `wxentity.action.open` | `module.abilities[].skills` | 让微信确认收款后的回跳 `Want` 能路由回宿主 Ability | **拉起完全正常**（确认收款页照样打开），但结果取不到：`onMerchantTransferResult` 不触发、`getLastMerchantTransferResult()` 恒为 `null` |

在 `entry/src/main/module.json5` 中按下面的**层级**配置（注意 `actions` 不在 `module` 下，必须嵌在 `abilities[].skills[]` 内）：

```json5
{
  "module": {
    // ...
    "querySchemes": ["weixin"],
    "abilities": [
      {
        "name": "EntryAbility",
        // ...
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

> 早期版本文档把 `actions` 与 `querySchemes` 平级写在 `module` 节点下，是错的 —— 照抄不会生成预期的 intent 过滤，回跳同样收不到。若你已按旧片段配置过，请重新核对层级。

#### 两类工程的落地方式

`manifest.json` 里没有任何开关能生成这两项，只能落到原生 `module.json5`；区别在于改哪一份、改完会不会被后续构建冲掉：

- **HBuilderX 工程（发行 → App-Harmony-本地打包）**：`module.json5` 属于打包生成的中间产物，直接改容易被重新生成覆盖。建议通过项目根目录 `harmony-configs/` 提供**完整的** `module.json5` 覆盖（该目录内文件是原样整体覆盖，不能只给片段）；注意 `manifest.json` 中的鸿蒙配置优先级高于 `harmony-configs`。
- **uni-app cli 工程 / 自维护原生权威工程**（配套 demo 与多数离线打包工程属此类）：`entry/src/main/module.json5` 是长期存在的源文件，直接编辑即可。但如果你的构建脚本会用模板重新生成整个 `entry` 目录，请把这两项写进模板、或在脚本里加一步 patch，否则改动会被下一次构建冲掉。

**改完必须重新构建并安装 HAP 才生效**：`module.json5` 编译进 HAP，WGT 热更新、替换 `www` 目录都不起作用。落地后建议做产物级确认 —— 解包 HAP 检查其中的 `module.json` 是否真的带上了 `querySchemes` 与 `wxentity.action.open`，不要只看源文件。

### 2.3 微信回跳 Want 的接收（插件自动完成，无需改原生）

插件加载时通过 `UTSHarmony.onAppAbilityCreate` / `UTSHarmony.onAppAbilityNewWant` 监听宿主 `EntryAbility` 生命周期，自行接管微信回跳的 `Want` 并交给微信 SDK 分发。前者覆盖冷启动回跳，后者覆盖应用存活时的回跳。

因此 **HBuilderX 工程（鸿蒙只有本地打包，不存在云打包）不需要修改任何原生代码**，完成 2.1、2.2 后即可直接使用。若确实要改动生成的原生文件，可通过项目根目录下的 `harmony-configs` 目录覆盖：该目录内文件是**原样整体覆盖**（因此必须提供完整文件而非片段），且 `manifest.json` 中的鸿蒙配置优先级高于 `harmony-configs`。

> 前提：插件必须被前端静态引用才会进入编译范围（见第四节注意事项 7），否则钩子不会安装。

#### 冷启动回跳（App 已被系统回收）

用户长时间停留在微信确认收款页面、宿主进程被回收时，回跳走 `onCreate`，此时插件还未调起过、内部没有 `WXApi` 实例，无法确定 appId。两种处理方式：

- 在 `App.vue` 的 `onLaunch` 里调一次 `setMerchantTransferAppId('wxYourAppId')`（推荐，一行代码，无原生改动）；
- 或忽略：插件会把该 Want 暂存，待下一次 `requestMerchantTransfer` 或 `setMerchantTransferAppId` 时自动补投。

```vue
<script setup>
// #ifdef APP-HARMONY
import { setMerchantTransferAppId } from '@/uni_modules/xyyt-wxmerchanttransfer'
setMerchantTransferAppId('wxYourAppId')
// #endif
</script>
```

### 2.4 可选：自维护原生工程手工转发 Want

仅在以下场景需要：你自己的鸿蒙工程直接持有 `EntryAbility`（离线打包 / 原生权威工程），且希望在原生层显式控制分发时机。常规接入无需本节。

```ets
import { handleWeChatWant } from '@uni_modules/xyyt-wxmerchanttransfer'

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

> 不要与自动接管叠加：若宿主已手工转发，插件内部钩子会再转发一次，同一 Want 被 `handleWant` 两次。微信 SDK 对非本插件类型的 resp 会忽略，但为避免歧义，两种方式二选一即可。

### 2.5 页面调用

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
| fail | callback | 否 | 调起失败（参数缺失 / querySchemes 未配置 / 未安装微信或版本过低 / 发送失败） |
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
2. **UTS 产物属原生层，插件自身升级需重打包**：插件代码被编译为 ArkTS 打进 HAP，不在 JS 层，因此插件版本升级无法靠 WGT 热更新覆盖；但接入本身已不需要宿主改原生代码，不再为此维护原生工程。
3. **重复调起**：`onMerchantTransferResult` 为一次性回调；同一时刻仅保留最后一次注册。重复调起前建议先处理上一次结果（或改用轮询 API）。
4. **依赖冲突**：若宿主同时集成微信登录插件（uni-oauth-weixin），其传递依赖同为 `@tencent/wechat_open_sdk`，ohpm 自动去重，无需处理；若出现版本不一致，可在鸿蒙工程根 `oh-package.json5` 的 `overrides` 中统一版本。
5. **服务商模式**：传 `subAppId`/`subMchId` 时 query 由微信侧校验，`mchId` 传服务商商户号。
6. **uni-app x**：本插件仅在 uni-app（vue3）鸿蒙端验证，因此 `package.json` 中 uni-app x 鸿蒙声明为不支持（`-`）。uvue / uni-app x 工程请勿直接引用；如确有需求，请先自行验证编译与运行，后续版本可据验证结果再开放。
7. **HBuilderX 工程须保留一条页面静态 import**：UTS 插件只有在被前端静态引用时才会纳入编译范围。若只在原生 `EntryAbility` 引用 `handleWeChatWant`、页面侧无任何 import，HBuilderX 不会编译 `utssdk/app-harmony/index.uts`，运行时 `uni.requireUTSPlugin` 返回 undefined。请在任一 `#ifdef APP-HARMONY` 页面保留 `import ... from '@/uni_modules/xyyt-wxmerchanttransfer'`（demo 页即示例）。改动插件引用关系后，需先删除工程 `dist/`（HBuilderX 工程为 `unpackage/`）再重新运行，否则会复用旧的“未被引用”判定。对普通插件这只是编译问题，对本插件则是功能前提：生命周期钩子在插件模块加载时才安装，插件没进编译范围就等于钩子不存在，调起依然能发起、但确认结果永远回不来。

---

## 五、Demo

配套 demo 工程（uni-app cli，vue3）以 `src/pages/index/index.vue` 演示完整流程（参数输入 → 调起 → 结果回调与轮询展示），插件源码位于 `src/uni_modules/xyyt-wxmerchanttransfer/`。真机验证只需按 2.1、2.2 完成（插件自动接管 Want，无需改原生）；2.2 的两项配置少一项就会出现「拉得起但取不到结果」或「报未能拉起微信（并提示 querySchemes 未配置）」，建议按该节末尾的产物级方式先确认再上机。

## 六、已知限制

- 仅鸿蒙端生效；Android/iOS 请用官方插件（本插件不重复实现）。
- 结果回传依赖微信回跳 `Want` 被成功分发，**且依赖 `module.json5` 的 `wxentity.action.open`**（见 2.2）：缺该 action 时拉起不受任何影响，但回跳 Want 路由不回宿主，结果恒为空。
- 常规场景由插件内部 UTSHarmony 钩子自动接管；若插件未被前端静态引用（注意事项 7）或宿主 uni-app 编译工具链低于 4.31，钩子装不上，此时调起可发起但收不到确认结果，需升级工具链或按 2.4 手工转发。
- 已获真机结论的机制：`onAppAbilityNewWant`（应用存活时回跳）+ 一次性回调 + 轮询读取，2026-11-18 独立插件工程真机返回 `{"result":"cancel"}`。
- **尚无真机结论的机制**：`onAppAbilityCreate` 冷启动回跳与「暂存 Want 后续自动补投」，目前仅有工程与编译层证据。若你的场景回跳异常，先用 `getLastMerchantTransferResult()` 轮询定位，并核对 2.2 的两项配置。
