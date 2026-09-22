import ScriptTracker
import SwiftUI

struct ContentView: View {
    @State private var model = SpikeModel()
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // 진단용 UI는 큰 글씨에서도 대본 영역을 밀어내지 않도록 크기를 제한한다. 대본·전사는 그대로 커진다.
                Group {
                    statusHeader
                    scriptPicker
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
                scriptView
                transcriptView
                Group {
                    metricsView
                    controls
                }
                .dynamicTypeSize(...DynamicTypeSize.large)
            }
            .padding()
            .navigationTitle("STT 스파이크")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("로그") { showLog = true }
                }
            }
            .sheet(isPresented: $showLog) {
                LogSheet(model: model)
            }
        }
        .task { await model.checkSupport() }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.localeReport)
            Text(model.formatReport)
            Text("상태: \(model.status)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var scriptPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("대본", selection: $model.script) {
                ForEach(SampleScript.all) { script in
                    Text(script.title).tag(script)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isRunning)
            Text(model.script.instruction)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var scriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                FlowLayout {
                    ForEach(model.session.tokens, id: \.index) { token in
                        TokenView(token: token, state: tokenState(for: token.index))
                            .id(token.index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200, maxHeight: .infinity)
            .onChange(of: model.session.cursor) { _, cursor in
                guard cursor > 0 else { return }
                withAnimation { proxy.scrollTo(cursor - 1, anchor: .center) }
            }
        }
    }

    /// 커서 앞은 읽은 것. 강조 위치는 토글에 따라 "방금 읽은 어절"(cursor-1) 또는 "다음 어절"(cursor).
    private func tokenState(for index: Int) -> TokenState {
        let cursor = model.session.cursor
        let current = model.highlightNextToken ? cursor : cursor - 1
        if index == current { return .current }
        return index < cursor ? .done : .upcoming
    }

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("전사")
                .font(.caption)
                .foregroundStyle(.secondary)
            // 임시 결과는 미확정 구간 전체라 길어질 수 있다. 끝부분만 보여 준다.
            Text("\(model.finalizedText.suffix(40))\(Text(model.volatileText.suffix(80)).foregroundStyle(.secondary))")
                .font(.body)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var metricsView: some View {
        HStack {
            metric("커서", "\(model.session.cursor)/\(model.session.tokens.count)")
            metric("결과", "\(model.finalCount)확정 \(model.volatileCount)임시")
            metric("갱신 주기", model.averageUpdateInterval.map { String(format: "%.2fs", $0) } ?? "-")
            metric("확정 지연", model.averageFinalLag.map { String(format: "%.2fs", $0) } ?? "-")
        }
        .font(.caption)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit().fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Toggle("fastResults", isOn: $model.useFastResults)
                Toggle("대본 힌트", isOn: $model.useContextualWords)
                Toggle("받아쓰기", isOn: $model.preferDictation)
            }
            .font(.footnote)
            .disabled(model.isRunning)
            Toggle("다음 어절 강조 (프롬프터 방식)", isOn: $model.highlightNextToken)
                .font(.footnote)
            HStack {
                Text("임계값 \(model.maxDistance, format: .number.precision(.fractionLength(2)))")
                    .font(.footnote)
                    .monospacedDigit()
                Slider(value: $model.maxDistance, in: 0.2...0.7, step: 0.05)
                    .disabled(model.isRunning)
            }
            HStack(spacing: 12) {
                Button(model.isRunning ? "정지" : "시작", systemImage: model.isRunning ? "stop.fill" : "mic.fill") {
                    model.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isRunning ? .red : .accentColor)
                Button("다음 어절", systemImage: "arrow.right") { model.advanceManually() }
                    .buttonStyle(.bordered)
                Button("처음부터", systemImage: "arrow.counterclockwise") { model.resetSession() }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning)
            }
            .frame(minHeight: 44)
        }
    }
}

private enum TokenState { case done, current, upcoming }

/// 어절 하나. 읽은 것은 흐리게, 강조 어절은 노란 배경, 아직 안 읽은 것은 기본.
/// 입력을 enum으로 받아 커서가 움직여도 상태가 바뀐 2개만 body를 다시 그린다.
private struct TokenView: View {
    let token: ScriptToken
    let state: TokenState

    var body: some View {
        Text(token.text)
            .font(.title2)
            .fontWeight(state == .current ? .bold : .regular)
            .foregroundStyle(state == .done ? .secondary : .primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(state == .current ? Color.yellow.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(state == .current ? "현재 어절 \(token.text)" : token.text)
    }
}

private struct LogSheet: View {
    let model: SpikeModel

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(model.exportLog())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("로그")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: model.exportLog()) {
                        Label("공유", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
