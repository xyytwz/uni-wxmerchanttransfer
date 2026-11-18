# 1.0.0 (2026-11-18)

- 首个版本：鸿蒙端微信商家转账用户确认收款（requestMerchantTransfer）
- 调起字段对齐官方 uni.requestMerchantTransfer（mchId/appId/package/openId/subAppId/subMchId）
- 鸿蒙增强：onMerchantTransferResult 一次性回调 + getLastMerchantTransferResult 轮询读取用户确认结果（success|fail|cancel）
- 依赖 @tencent/wechat_open_sdk 1.0.23
- 微信回跳 Want 由插件内部 UTSHarmony.onAppAbilityCreate / onAppAbilityNewWant 自动接管（版本门槛：@dcloudio/uni-app-runtime 的 UTSHarmony.d.ts 标注 harmony.uniUtsPlugin = 4.31，即 uni-app 鸿蒙 UTS 插件 ≥ 4.31），宿主无需修改原生代码
- 宿主必选配置为**两项**（缺一不可）：module.json5 的 querySchemes: ["weixin"] 管拉起，abilities[].skills[].actions 含 wxentity.action.open 管回跳；缺后者时调起仍成功但确认结果取不到
- 新增 setMerchantTransferAppId(appId) 兼容冷启动回跳（App 被回收后插件尚无 WXApi 实例）；保留 handleWeChatWant 供自维护原生工程的宿主显式转发
- 已在 uni-app（vue3）+ 自定义原生壳工程 + 真机（HarmonyOS NEXT）验证；2026-11-18 于独立插件工程（uni-app cli + demo）真机跑通自动接管全链路，宿主原生零改动情况下微信回跳返回 {"result":"cancel"}（onAppAbilityNewWant 路径；onAppAbilityCreate 冷启动回跳尚无真机结论）
- 拉起失败成因分流：插件自己再调一次 canOpenLink("weixin://")，抛异常（实测 code 17700056）时按“宿主 querySchemes 未配置”报错并给出修复动作，不抛异常仍失败才提示未安装/版本过低；避免配置缺失被微信 SDK 吞成 isWXAppInstalled()=false 后误导用户去装微信
- 日志脱敏：调起时不再把完整 query 打进 hilog（内含一次性转账单据令牌 package_info 与用户标识 openId），改为只输出可选字段的键名
- 兼容性门槛：鸿蒙 API 12（5.0.0(12)）及以上——@tencent/wechat_open_sdk 1.0.23 与 @dcloudio/uni-app-runtime 均声明 compatibleSdkVersion: 12，低于 API 12 依赖装不上；已在 API 12 与 API 13 真机验证
- engines.HBuilderX 采用 >=4.31 而非 ^4.31，避免 4.31 之后的大版本被 semver 判为不兼容（实测环境：uni-app vue3 + @dcloudio/* 3.0.0-5020620260917001）
