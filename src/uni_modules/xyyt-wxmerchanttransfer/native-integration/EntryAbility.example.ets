/**
 * 宿主 EntryAbility 集成示例（xyyt-wxmerchanttransfer）
 *
 * 将 onCreate / onNewWant 中的 handleWeChatWant(want) 转发调用合入你的 EntryAbility。
 * 该文件仅为示例，不参与插件编译；请把改动落到你的鸿蒙原生工程
 * entry/src/main/ets/entryability/EntryAbility.ets 中。
 *
 * 注意：原生工程内引用插件编译产物使用模块名（插件 id 全小写）：
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
