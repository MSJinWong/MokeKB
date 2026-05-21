/**
 * 品牌常量集中位 —— 后续替换产品名时只动这里。
 *
 * 当前为占位值，用户提供品牌素材后填入实际产品名与口号。
 * 用法：import { PRODUCT_NAME } from '@/utils/brand'
 *
 * 说明：
 * - 不要修改 window.MaxKB（嵌入合约 JS API，外部依赖）
 * - 不要修改 localStorage 的 'MaxKB-locale' key（向后兼容）
 * - 仅用于替换组件 / 模板中的 USER-VISIBLE 产品名文字
 */
export const PRODUCT_NAME = '产品名'
export const PRODUCT_NAME_EN = 'ProductName'
export const PRODUCT_SLOGAN = '企业知识与智能体平台'
export const PRODUCT_SLOGAN_EN = 'Enterprise knowledge & agent platform'
