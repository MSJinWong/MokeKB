"""
保留原导入路径，实际转发给 models_provider.registry。
旧代码 from models_provider.constants.model_provider_constants import ModelProvideConstants
仍然可用。
"""
from models_provider.registry import ModelProvideConstants  # noqa: F401
