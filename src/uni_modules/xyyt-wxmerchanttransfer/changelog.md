# 1.0.0 (2026-11-18)

- 首个版本：鸿蒙端微信商家转账用户确认收款（requestMerchantTransfer）
- 调起字段对齐官方 uni.requestMerchantTransfer（mchId/appId/package/openId/subAppId/subMchId）
- 鸿蒙增强：onMerchantTransferResult 一次性回调 + getLastMerchantTransferResult 轮询读取用户确认结果（success|fail|cancel）
- 依赖 @tencent/wechat_open_sdk 1.0.23
- 微信回跳 Want 由插件内部 UTSHarmony.onAppAbilityCreate / onAppAbilityNewWant 自动接管（uni-app UTS 插件 ≥ 4.31），宿主无需修改原生代码；仅保留 querySchemes 一项必选配置
- 新增 setMerchantTransferAppId(appId) 兼容冷启动回跳（App 被回收后插件尚无 WXApi 实例）；保留 handleWeChatWant 供自维护原生工程的宿主显式转发
- 已在 uni-app（vue3）+ 自定义原生壳工程 + 真机（HarmonyOS NEXT）验证
- 配套博文《补上缺失的拼图：为 uni-app 鸿蒙端实现微信“商家转账确认收款”插件》即将发布于掘金 / 博客园，链接将在后续版本补充
