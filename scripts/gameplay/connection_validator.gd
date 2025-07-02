## Connection Validator
# @desc: 用于根据音节规则验证两个音节卡是否可以连接的静态工具类。
# @author: LexiLink
# @date: 2024-07-02
#
# 规则 (v1):
# 1. 元音 -> 辅音  ✅
# 2. 辅音 -> 元音/流音 ✅
# 3. 其他组合 ❌
# 未来: 替换为数据驱动的规则。

class_name ConnectionValidator
extends Object

static func validate_connection(from_card: SyllableCard, to_card: SyllableCard) -> bool:
    var from_type = from_card.syllable_type
    var to_type = to_card.syllable_type
    match from_type:
        SyllableCard.SyllableType.VOWEL:
            return to_type == SyllableCard.SyllableType.CONSONANT
        SyllableCard.SyllableType.CONSONANT:
            return to_type in [SyllableCard.SyllableType.VOWEL, SyllableCard.SyllableType.LIQUID]
        _:
            return false 