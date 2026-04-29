# coding=utf-8
"""
    @project: MaxKB
    @Author：虎
    @file： embedding.py
    @date：2024/7/12 17:44
    @desc:
"""
from typing import Dict, List

import openai

from models_provider.base_model_provider import MaxKBBaseModel


class OpenAIEmbeddingModel(MaxKBBaseModel):
    model_name: str
    optional_params: dict

    def __init__(self, api_key, base_url, model_name: str, optional_params: dict):
        self.client = openai.OpenAI(api_key=api_key, base_url=base_url).embeddings
        self.model_name = model_name
        self.optional_params = optional_params

    def is_cache_model(self):
        return False

    @staticmethod
    def new_instance(model_type, model_name, model_credential: Dict[str, object], **model_kwargs):
        optional_params = MaxKBBaseModel.filter_optional_params(model_kwargs)
        # dimensions 是用户在前端表单输入的字符串：空串表示不传给 server（用 server 默认）；
        # 非空则强制转 int，避免 OpenAI SDK 拒绝字符串。无效值（无法转 int）一律剔除。
        if 'dimensions' in optional_params:
            raw = optional_params['dimensions']
            if raw in (None, '', 0, '0'):
                optional_params.pop('dimensions')
            else:
                try:
                    optional_params['dimensions'] = int(raw)
                except (TypeError, ValueError):
                    optional_params.pop('dimensions')
        return OpenAIEmbeddingModel(
            api_key=model_credential.get('api_key'),
            model_name=model_name,
            base_url=model_credential.get('api_base'),
            optional_params=optional_params
        )

    def embed_query(self, text: str):
        res = self.embed_documents([text])
        return res[0]

    def embed_documents(
            self, texts: List[str], chunk_size: int | None = None
    ) -> List[List[float]]:
        if len(self.optional_params) > 0:
            res = self.client.create(
                input=texts, model=self.model_name, encoding_format="float",
                **self.optional_params
            )
        else:
            res = self.client.create(input=texts, model=self.model_name, encoding_format="float")
        return [e.embedding for e in res.data]
