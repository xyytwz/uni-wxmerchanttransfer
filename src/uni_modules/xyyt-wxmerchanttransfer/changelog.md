# 1.0.0 (2026-11-18)

- 首个版本：鸿蒙端微信商家转账用户确认收款（requestMerchantTransfer）
- 调起字段对齐官方 uni.requestMerchantTransfer（mchId/appId/package/openId/subAppId/subMchId）
- 鸿蒙增强：onMerchantTransferResult 一次性回调 + getLastMerchantTransferResult 轮询读取用户确认结果（success|fail|cancel）
- 依赖 @tencent/wechat_open_sdk 1.0.23；宿主需在 EntryAbility onCreate/onNewWant 转发 handleWeChatWant(want)
- 已在 uni-app（vue3）+ 自定义原生壳工程 + 真机（HarmonyOS NEXT）验证
- 配套博文：掘金 https://juejin.cn/post/TODO · 博客园 https://www.cnblogs.com/TODO（发布后回填）
