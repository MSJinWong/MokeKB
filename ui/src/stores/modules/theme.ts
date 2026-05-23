import { defineStore } from 'pinia'
import { cloneDeep } from 'lodash'
import { defaultPlatformSetting } from '@/utils/theme'

export interface themeStateTypes {
  themeInfo: any
}

const useThemeStore = defineStore('theme', {
  state: (): themeStateTypes => ({
    themeInfo: { ...defaultPlatformSetting },
  }),
  actions: {
    isDefaultTheme() {
      return true
    },
    setTheme(data?: any) {
      this.themeInfo = data ? cloneDeep(data) : { ...defaultPlatformSetting }
    },
  },
})

export default useThemeStore
