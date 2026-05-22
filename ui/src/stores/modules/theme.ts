import { defineStore } from 'pinia'
import { cloneDeep } from 'lodash'
import ThemeApi from '@/api/system-settings/theme'
import type { Ref } from 'vue'

export interface themeStateTypes {
  themeInfo: any
}

/**
 * 品牌色固定由 CSS token 控制(`--brand-primary` / `--el-color-primary`)。
 * 此 store 仅保留非颜色相关的平台外观信息(站名/口号/logo/外链)。
 * 历史上有运行时 changeTheme() 行为,会把 EP 主色刷成 #3370FF (MaxKB 蓝),已移除。
 */
const useThemeStore = defineStore('theme', {
  state: (): themeStateTypes => ({
    themeInfo: null,
  }),
  actions: {
    isDefaultTheme() {
      return true
    },

    setTheme(data?: any) {
      this.themeInfo = cloneDeep(data)
    },

    async theme(loading?: Ref<boolean>) {
      return await ThemeApi.getThemeInfo(loading).then((ok) => {
        this.setTheme(ok.data)
      })
    },
  },
})

export default useThemeStore
