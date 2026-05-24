"""
Provider 懒加载注册表。

兼容旧 ModelProvideConstants[name].value 与 ModelProvideConstants.__members__ 的访问形态。
真实加载时机：第一次按 name 取值或迭代成员。

启用方式：
- 不设置 MAXKB_ENABLED_PROVIDERS：使用 _DEFAULT_ENABLED 白名单（轻量精简部署默认）
- MAXKB_ENABLED_PROVIDERS=all：注册全部 provider
- MAXKB_ENABLED_PROVIDERS=foo,bar：仅启用名单内的 provider
"""
import importlib
import os
import threading
from typing import Dict, Iterable, Tuple


# (key) -> (module path, class name)
_PROVIDER_PATHS: Dict[str, Tuple[str, str]] = {
    'model_azure_provider':
        ('models_provider.impl.azure_model_provider.azure_model_provider', 'AzureModelProvider'),
    'model_wenxin_provider':
        ('models_provider.impl.wenxin_model_provider.wenxin_model_provider', 'WenxinModelProvider'),
    'model_ollama_provider':
        ('models_provider.impl.ollama_model_provider.ollama_model_provider', 'OllamaModelProvider'),
    'model_openai_provider':
        ('models_provider.impl.openai_model_provider.openai_model_provider', 'OpenAIModelProvider'),
    'model_docker_ai_provider':
        ('models_provider.impl.docker_ai_model_provider.docker_ai_model_provider', 'DockerModelProvider'),
    'model_kimi_provider':
        ('models_provider.impl.kimi_model_provider.kimi_model_provider', 'KimiModelProvider'),
    'model_zhipu_provider':
        ('models_provider.impl.zhipu_model_provider.zhipu_model_provider', 'ZhiPuModelProvider'),
    'model_xf_provider':
        ('models_provider.impl.xf_model_provider.xf_model_provider', 'XunFeiModelProvider'),
    'model_deepseek_provider':
        ('models_provider.impl.deepseek_model_provider.deepseek_model_provider', 'DeepSeekModelProvider'),
    'model_gemini_provider':
        ('models_provider.impl.gemini_model_provider.gemini_model_provider', 'GeminiModelProvider'),
    'model_volcanic_engine_provider':
        ('models_provider.impl.volcanic_engine_model_provider.volcanic_engine_model_provider', 'VolcanicEngineModelProvider'),
    'model_tencent_provider':
        ('models_provider.impl.tencent_model_provider.tencent_model_provider', 'TencentModelProvider'),
    'model_tencent_cloud_provider':
        ('models_provider.impl.tencent_cloud_model_provider.tencent_cloud_model_provider', 'TencentCloudModelProvider'),
    'model_aws_bedrock_provider':
        ('models_provider.impl.aws_bedrock_model_provider.aws_bedrock_model_provider', 'BedrockModelProvider'),
    'model_xinference_provider':
        ('models_provider.impl.xinference_model_provider.xinference_model_provider', 'XinferenceModelProvider'),
    'model_vllm_provider':
        ('models_provider.impl.vllm_model_provider.vllm_model_provider', 'VllmModelProvider'),
    'aliyun_bai_lian_model_provider':
        ('models_provider.impl.aliyun_bai_lian_model_provider.aliyun_bai_lian_model_provider', 'AliyunBaiLianModelProvider'),
    'model_anthropic_provider':
        ('models_provider.impl.anthropic_model_provider.anthropic_model_provider', 'AnthropicModelProvider'),
    'model_siliconCloud_provider':
        ('models_provider.impl.siliconCloud_model_provider.siliconCloud_model_provider', 'SiliconCloudModelProvider'),
    'model_regolo_provider':
        ('models_provider.impl.regolo_model_provider.regolo_model_provider', 'RegoloModelProvider'),
}

# 默认启用的精简白名单：5 公有云 + 4 本地部署，覆盖文本/图片/音频/视频四类模态
# 公有云：OpenAI(LLM/Embedding/IMAGE/STT/TTS/TTI) + Anthropic(LLM/IMAGE) +
#         SiliconFlow(Reranker 等) + 阿里百炼(全模态含 ITV/TTV) + 火山引擎(含 ITV/TTV)
# 本地  ：Ollama / vLLM / Xinference / Docker AI
_DEFAULT_ENABLED = [
    'model_openai_provider',
    'model_anthropic_provider',
    'model_siliconCloud_provider',
    'aliyun_bai_lian_model_provider',
    'model_volcanic_engine_provider',
    'model_ollama_provider',
    'model_vllm_provider',
    'model_xinference_provider',
    'model_docker_ai_provider',
]

# 单一全局 _lock 用于：
# (1) _Registry._ensure 中的成员字典构建（一次性）
# (2) _Member.value 中的 provider 实例化（每个 provider 一次）
# 两者从不嵌套调用，因此用普通 Lock 而非 RLock 没有死锁风险；
# 如未来出现嵌套，请改为 RLock。
_lock = threading.Lock()


def _enabled_keys() -> list:
    raw = os.environ.get('MAXKB_ENABLED_PROVIDERS')
    if not raw:
        return list(_DEFAULT_ENABLED)
    keys = [k.strip() for k in raw.split(',') if k.strip()]
    if keys == ['all'] or keys == ['*']:
        return list(_PROVIDER_PATHS.keys())
    unknown = [k for k in keys if k not in _PROVIDER_PATHS]
    if unknown:
        try:
            from common.utils.logger import maxkb_logger
            maxkb_logger.warning(f'Unknown provider keys ignored: {unknown}')
        except Exception:
            pass
    return [k for k in keys if k in _PROVIDER_PATHS]


class _Member:
    __slots__ = ('name', '_value')

    def __init__(self, name: str):
        self.name = name
        self._value = None

    @property
    def value(self):
        if self._value is None:
            with _lock:
                if self._value is None:
                    module_path, class_name = _PROVIDER_PATHS[self.name]
                    cls = getattr(importlib.import_module(module_path), class_name)
                    self._value = cls()
        return self._value


class _Registry:
    def __init__(self):
        self._members = None

    def _ensure(self):
        if self._members is None:
            with _lock:
                if self._members is None:
                    self._members = {k: _Member(k) for k in _enabled_keys()}

    @property
    def __members__(self) -> Dict[str, _Member]:
        self._ensure()
        return self._members

    def __getitem__(self, key: str) -> _Member:
        self._ensure()
        if key not in self._members:
            raise KeyError(f'Provider {key} is not enabled (MAXKB_ENABLED_PROVIDERS).')
        return self._members[key]

    def __iter__(self) -> Iterable[_Member]:
        self._ensure()
        return iter(self._members.values())

    def __contains__(self, key: str) -> bool:
        self._ensure()
        return key in self._members


ModelProvideConstants = _Registry()
