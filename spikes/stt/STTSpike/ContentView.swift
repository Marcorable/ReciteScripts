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
                        TokenView(token: token, cursor: model.session.cursor)
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

    private var transcriptView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("전사")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(model.finalizedText.suffix(60))\(Text(model.volatileText).foregroundStyle(.secondary))")
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
            metric("지연 평균", model.averageLag.map { String(format: "%.2fs", $0) } ?? "-")
            metric("최대", model.maxLag.map { String(format: "%.2fs", $0) } ?? "-")
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
            }
            .font(.footnote)
            .disabled(model.isRunning)
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

/// 어절 하나. 읽은 것은 흐리게, 방금 읽은 것은 노란 배경, 아직 안 읽은 것은 기본.
private struct TokenView: View {
    let token: ScriptToken
    let cursor: Int

    var body: some View {
        Text(token.text)
            .font(.title2)
            .fontWeight(isCurrent ? .bold : .regular)
            .foregroundStyle(isDone ? .secondary : .primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isCurrent ? Color.yellow.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel(isCurrent ? "현재 어절 \(token.text)" : token.text)
    }

    private var isDone: Bool { token.index < cursor - 1 }
    private var isCurrent: Bool { token.index == cursor - 1 }
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
