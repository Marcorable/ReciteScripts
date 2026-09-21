import Foundation

/// 테스트용 대본. 전부 직접 쓴 더미 문장이다 (AGENTS.md 3번: 제3자 텍스트 금지).
struct SampleScript: Identifiable, Hashable {
    let id: String
    let title: String
    let instruction: String
    let body: String

    static let all: [SampleScript] = [
        SampleScript(
            id: "daily",
            title: "① 일상",
            instruction: "평소 말하는 속도와 크기로 읽는다.",
            body: """
            오늘 아침에는 창문을 열고 바깥 공기를 천천히 마셨다. \
            골목 끝 빵집에서 갓 구운 빵 냄새가 바람을 타고 올라왔다. \
            나는 주전자에 물을 올리고 어제 읽다 만 책을 펼쳤다. \
            첫 장을 넘기기도 전에 전화가 울렸고, 동생은 주말에 같이 산에 가자고 했다. \
            나는 잠깐 망설이다가 그러자고 대답했다. \
            창밖에서는 이웃집 아이가 자전거 타는 법을 배우고 있었다. \
            넘어지고, 일어나고, 다시 페달을 밟는 소리가 오래 이어졌다.
            """
        ),
        SampleScript(
            id: "fast",
            title: "② 빠르고 작게",
            instruction: "숨 한 번에 한 줄씩, 속삭이듯 빠르게 읽는다.",
            body: """
            문을 닫고 불을 끄고 가방을 메고 계단을 내려간다. \
            버스는 벌써 떠났고 다음 차는 십 분 뒤에 온다. \
            편의점에 들러 우유 하나 김밥 하나 물 한 병을 산다. \
            정류장 벤치에 앉아 어제 못 본 메시지를 하나씩 읽는다. \
            비가 올 것 같아서 우산을 챙겼는데 하늘은 금세 맑아졌다. \
            그래도 가방에 넣어 둔 우산이 괜히 든든하다.
            """
        ),
        SampleScript(
            id: "sino",
            title: "③ 음독·음차",
            instruction: "한 글자씩 또박또박, 음을 따라 읽는다. 뜻은 없는 소리다.",
            body: """
            천지현명 일월성진 산고수장 풍청월백 \
            동서남북 춘하추동 만사형통 무병장수 \
            타로미 세나가 루비타 온다라 미소카 바니라 \
            토로사 나비카 아루미 텐다로 소미나 카란테 \
            일이삼사 오륙칠팔 구십백천 만억조경 \
            가나다라 마바사아 자차카타 파하
            """
        ),
    ]
}
