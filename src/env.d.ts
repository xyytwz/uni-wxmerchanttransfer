/// <reference types="vite/client" />

declare module '*.vue' {
  import { DefineComponent } from 'vue'
  const component: DefineComponent<object, object, any>
  export default component
}

declare module '@dcloudio/uni-app' {
  export type OnUnmounted = () => void
}
