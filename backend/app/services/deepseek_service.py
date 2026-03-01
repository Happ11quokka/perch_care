"""
DeepSeek Chinese cultural supplement service.

Provides supplementary context about Chinese pet bird culture,
products, and practices via DeepSeek API. Used as an optional
enrichment layer for premium users — failures are silently ignored.
"""
import logging

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)

settings = get_settings()

DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

TEXT_SUPPLEMENT_PROMPT = """你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

针对以下用户问题，请提供中国特有的补充背景信息，包括但不限于：
- 中国鸟友圈的常见做法和经验
- 中国市场上可获得的相关产品（药品、饲料、器具等）
- 中医/传统方法在鸟类护理中的应用（如有）
- 中国特有的鸟类品种或饲养习惯

重要：你只提供补充信息，不做最终医学诊断。最终判断将由主AI完成。
回答控制在200-400字。

用户问题：{query}"""

VISION_SUPPLEMENT_PROMPT = """你是一位熟悉中国宠物鸟饲养文化的鸟类专家。

用户上传了一张关于"{mode}"的照片。
针对这个分析类型，请补充中国特有的背景信息：

- 如果是排便(droppings)：中国鸟友判断排便健康的经验方法
- 如果是食物(food)：中国市场常见的鸟粮品牌、本地食材的安全性
- 如果是鸟的外观：中国常见品种的特征差异、本地常见疾病

用户补充说明：{query}

重要：你只提供补充信息，不做最终诊断。
回答控制在150-300字。"""


async def get_chinese_supplement(
    query: str,
    mode: str = "text",
    timeout: float = 5.0,
) -> str | None:
    """Generate Chinese cultural context supplement via DeepSeek API.

    Returns None on any failure (missing key, timeout, API error)
    so the main AI pipeline continues uninterrupted.
    """
    if not settings.deepseek_api_key:
        return None

    if mode == "text":
        prompt = TEXT_SUPPLEMENT_PROMPT.format(query=query)
    else:
        prompt = VISION_SUPPLEMENT_PROMPT.format(mode=mode, query=query)

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(
                DEEPSEEK_API_URL,
                headers={
                    "Authorization": f"Bearer {settings.deepseek_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "deepseek-chat",
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.3,
                    "max_tokens": 500,
                },
            )
            response.raise_for_status()
            data = response.json()
            return data["choices"][0]["message"]["content"]
    except httpx.TimeoutException:
        logger.warning("DeepSeek API timed out after %.1fs", timeout)
        return None
    except Exception as e:
        logger.warning("DeepSeek API call failed: %s", e)
        return None
