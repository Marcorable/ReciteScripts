import SwiftUI

/// 검증 루프(빌드 → 테스트 → 시뮬레이터 → 스크린샷)가 동작하는지 확인하기 위한 최소 화면.
/// 실제 앱 화면은 3단계 Walking Skeleton에서 만든다.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("빌드 검증")
                .font(.largeTitle.bold())
            Text(BuildInfo.greeting)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

/// 유닛 테스트가 앱 타깃 코드를 볼 수 있는지 확인하는 용도.
enum BuildInfo {
    static let greeting = "검증 루프가 동작합니다"
}

#Preview {
    ContentView()
}
