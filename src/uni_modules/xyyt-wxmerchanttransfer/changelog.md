## 1.0.0 (2026-11-18)
首个版本，聚焦 uni-app 鸿蒙端（HarmonyOS NEXT）微信商家转账/提现的「用户确认收款」环节。

- 调起微信确认收款页面，字段与官方 uni.requestMerchantTransfer 完全一致（mchId / appId / package / openId / subAppId / subMchId），可直接作为鸿蒙分支替换使用
- 回传用户确认结果（success / fail / cancel）：一次性回调 onMerchantTransferResult + 轮询式 getLastMerchantTransferResult，补齐官方插件在鸿蒙端缺失的能力
- 微信回跳 Want 由插件内部 UTSHarmony 生命周期钩子自动接管，宿主无需修改原生代码（需 HBuilderX / uni-app 编译工具链 ≥ 4.31）
- 宿主必配两项，缺一不可：module.querySchemes 含 "weixin"（管拉起）、abilities[].skills[].actions 含 "wxentity.action.open"（管回跳）
- 拉起失败自动分流成因：querySchemes 未配置时明确提示并给出修改位置，不再误报「未安装微信」
- 冷启动兜底 setMerchantTransferAppId(appId)；自维护原生工程可用 handleWeChatWant(want) 显式转发
- 日志不输出 package_info / openId 等凭据
- 依赖 @tencent/wechat_open_sdk 1.0.23，要求微信客户端 ≥ 8.0.11.34
- 真机验证：HarmonyOS NEXT + uni-app vue3，微信侧取消回跳全链路已跑通（onNewWant 路径）；onCreate 冷启动回跳暂无真机结论
- 范围：仅覆盖「用户确认收款」环节，发起转账仍需后端调用微信支付商家转账接口
