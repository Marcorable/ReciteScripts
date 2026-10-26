import Foundation

/// 비교 전 텍스트 정규화. 공백·문장부호·기호를 제거하고 한글 음절을 자모로 분해한다.
///
/// 음절 단위 비교는 "읽"과 "일"을 완전히 다른 글자로 보지만, 자모 단위로는 3개 중 2개가 같다.
/// STT 오인식은 받침 하나가 빠지는 식으로 나타나는 경우가 많아 자모 비교가 유사도를 더 잘 반영한다.
public enum TextNormalizer {
    /// 공백·문장부호·기호를 제거하고 소문자로 만든 뒤 NFD로 분해한다.
    public static func normalize(_ text: String) -> String {
        let kept = text.unicodeScalars.filter { scalar in
            let properties = scalar.properties
            return properties.isAlphabetic || properties.numericType != nil
        }
        return String(String.UnicodeScalarView(kept))
            .lowercased()
            .decomposedStringWithCanonicalMapping
    }

    /// 정규화된 문자열의 비교 단위 배열. 한글은 자모 하나가 한 단위다.
    public static func units(_ text: String) -> [Unicode.Scalar] {
        Array(normalize(text).unicodeScalars)
    }
}
