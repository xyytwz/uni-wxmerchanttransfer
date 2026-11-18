<template>
  <view class="wrap">
    <text class="title">微信商家转账确认收款 Demo</text>
    <text class="desc">鸿蒙端调起微信 requestMerchantTransfer 确认收款页面；用户在微信确认/取消后回跳 App，通过 onMerchantTransferResult 收到确认结果。</text>

    <view class="field">
      <text class="label">mchId 商户号</text>
      <input v-model="mchId" class="ipt" placeholder="微信支付商户号，如 1900000109" />
    </view>
    <view class="field">
      <text class="label">appId 微信开放平台 AppID</text>
      <input v-model="appId" class="ipt" placeholder="微信开放平台 AppID，如 wx1234567890abcdef" />
    </view>
    <view class="field">
      <text class="label">package 转账单据 package_info</text>
      <input v-model="packageInfo" class="ipt" placeholder="后端转账单据应答中的 package_info" />
    </view>

    <button class="btn" type="primary" @click="startTransfer">发起确认收款</button>
    <button class="btn-plain" @click="checkLast">查询最近一次结果（轮询式）</button>

    <view class="box" v-if="launchResult !== ''">
      <text class="box-title">调起结果</text>
      <text class="box-content">{{ launchResult }}</text>
    </view>
    <view class="box" v-if="confirmResult !== ''">
      <text class="box-title">用户确认结果</text>
      <text class="box-content">{{ confirmResult }}</text>
    </view>

    <view class="tips">
      <text class="tips-title">注意事项</text>
      <text class="tips-item">1. result=success 仅代表微信确认收款页面展示成功，不代表确认成功，到账以订单/列表接口为准。</text>
      <text class="tips-item">2. 真机需完成原生集成：module.json5 配 querySchemes=["weixin"]，EntryAbility onCreate/onNewWant 调 handleWeChatWant(want)。详见插件 readme.md。</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onUnmounted } from 'vue'
// #ifdef APP-HARMONY
import {
  requestMerchantTransfer,
  onMerchantTransferResult,
  offMerchantTransferResult,
  getLastMerchantTransferResult,
  clearMerchantTransferResult
} from '@/uni_modules/xyyt-wxmerchanttransfer'
// #endif

const mchId = ref('')
const appId = ref('')
const packageInfo = ref('')
const launchResult = ref('')
const confirmResult = ref('')
let pollTimer: ReturnType<typeof setInterval> | null = null

// #ifdef APP-HARMONY
// 注册一次性确认结果回调（微信回跳后触发并自动注销）
onMerchantTransferResult((res) => {
  confirmResult.value = 'result=' + res.result + '\nextMsg=' + res.errMsg
  uni.showToast({
    title: res.result === 'success' ? '微信确认收款页已打开' : '确认结果：' + res.result,
    icon: 'none'
  })
})
// #endif

function startTransfer() {
  launchResult.value = ''
  confirmResult.value = ''
  // #ifdef APP-HARMONY
  if (mchId.value === '' || appId.value === '' || packageInfo.value === '') {
    uni.showToast({ title: '请先填写 mchId / appId / package', icon: 'none' })
    return
  }
  clearMerchantTransferResult()
  requestMerchantTransfer({
    mchId: mchId.value,
    appId: appId.value,
    package: packageInfo.value,
    success: (res) => {
      launchResult.value = '拉起成功：' + res.errMsg
      startPoll()
    },
    fail: (res) => {
      launchResult.value = '拉起失败：' + res.errMsg
      uni.showToast({ title: res.errMsg, icon: 'none' })
    }
  })
  // #endif
  // #ifndef APP-HARMONY
  uni.showToast({ title: '本 demo 仅在鸿蒙端可调起微信', icon: 'none' })
  // #endif
}

/** 轮询式读取备用演示（与一次性回调二选一即可） */
function startPoll() {
  stopPoll()
  pollTimer = setInterval(() => {
    // #ifdef APP-HARMONY
    const r = getLastMerchantTransferResult()
    if (r != null) {
      stopPoll()
      confirmResult.value = 'result=' + r.result + '\nextMsg=' + r.errMsg
    }
    // #endif
  }, 1000)
}

function checkLast() {
  // #ifdef APP-HARMONY
  const r = getLastMerchantTransferResult()
  confirmResult.value = r != null ? 'result=' + r.result + '\nextMsg=' + r.errMsg : '暂无结果（调起后微信回跳才有）'
  // #endif
  // #ifndef APP-HARMONY
  uni.showToast({ title: '本 demo 仅在鸿蒙端可查询', icon: 'none' })
  // #endif
}

function stopPoll() {
  if (pollTimer != null) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

onUnmounted(() => {
  stopPoll()
  // #ifdef APP-HARMONY
  offMerchantTransferResult()
  // #endif
})
</script>

<style>
.wrap {
  padding: 40rpx 32rpx;
  display: flex;
  flex-direction: column;
}
.title {
  font-size: 36rpx;
  font-weight: 700;
  color: #222;
  margin-bottom: 16rpx;
}
.desc {
  font-size: 24rpx;
  color: #888;
  line-height: 1.6;
  margin-bottom: 32rpx;
}
.field {
  margin-bottom: 24rpx;
}
.label {
  font-size: 26rpx;
  color: #444;
  margin-bottom: 8rpx;
}
.ipt {
  height: 72rpx;
  padding: 0 20rpx;
  background-color: #fff;
  border-radius: 12rpx;
  font-size: 26rpx;
}
.btn {
  margin-top: 24rpx;
}
.btn-plain {
  margin-top: 16rpx;
}
.box {
  margin-top: 24rpx;
  padding: 24rpx;
  background-color: #fff;
  border-radius: 12rpx;
  display: flex;
  flex-direction: column;
}
.box-title {
  font-size: 26rpx;
  font-weight: 700;
  color: #333;
  margin-bottom: 8rpx;
}
.box-content {
  font-size: 24rpx;
  color: #666;
  line-height: 1.6;
  word-break: break-all;
}
.tips {
  margin-top: 40rpx;
  padding: 24rpx;
  background-color: #fff7ed;
  border-radius: 12rpx;
  display: flex;
  flex-direction: column;
}
.tips-title {
  font-size: 26rpx;
  font-weight: 700;
  color: #945c2b;
  margin-bottom: 8rpx;
}
.tips-item {
  font-size: 22rpx;
  color: #945c2b;
  line-height: 1.6;
  margin-bottom: 4rpx;
}
</style>
