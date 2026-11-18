/**
 * 宿主 EntryAbility 手工转发 Want 示例（xyyt-wxmerchanttransfer）—— 可选路径
 *
 * 常规接入不需要本文件：插件内部已通过
 *   UTSHarmony.onAppAbilityCreate / UTSHarmony.onAppAbilityNewWant
 * 自动接管微信回跳的 Want（uni-app HarmonyOS UTS 插件 ≥ 4.31），宿主无需改原生代码。
 *
 * 仅当你自己的鸿蒙工程直接持有 EntryAbility（离线打包 / 原生权威工程）
 * 且希望在原生层显式控制分发时机时才需合入下面两段调用。
 *
 * 注意：与自动接管二选一，不要叠加——同一 Want 被 handleWant 两次虽不致错，
 * 但会让分发时机变得难以预期。
 *
 * 该文件仅为示例，不参与插件编译；如需使用请把改动落到你的鸿蒙原生工程
 * entry/src/main/ets/entryability/EntryAbility.ets 中。
 *
 * 原生工程内引用插件编译产物使用模块名（插件 id 全小写）：
 *   @uni_modules/xyyt-wxmerchanttransfer
 */
import { UniEntryAbility } from '@dcloudio/uni-app-runtime';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { handleWeChatWant } from '@uni_modules/xyyt-wxmerchanttransfer';

export default class EntryAbility extends UniEntryAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 微信回跳转发（冷启场景：微信确认收款完成后拉回宿主走 onCreate）
    handleWeChatWant(want);
    super.onCreate(want, launchParam);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 微信回跳转发（热启场景）
    handleWeChatWant(want);
    super.onNewWant(want, launchParam);
  }
}
