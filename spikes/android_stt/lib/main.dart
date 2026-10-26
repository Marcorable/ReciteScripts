import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const SttSpikeApp());

class SttSpikeApp extends StatelessWidget {
  const SttSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const SttSpikePage(),
    );
  }
}

class SttSpikePage extends StatefulWidget {
  const SttSpikePage({super.key});

  @override
  State<SttSpikePage> createState() => _SttSpikePageState();
}

class _SttSpikePageState extends State<SttSpikePage>
    with WidgetsBindingObserver {
  static const _methods = MethodChannel(
    'dev.marcorable.recitescripts/stt_methods',
  );
  static const _events = EventChannel(
    'dev.marcorable.recitescripts/stt_events',
  );

  StreamSubscription<Object?>? _subscription;
  Map<String, Object?> _capabilities = const {};
  String _status = '초기화 중';
  String _transcript = '';
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: _onStreamError,
    );
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    final value = await _methods.invokeMapMethod<String, Object?>(
      'capabilities',
    );
    if (!mounted) return;
    setState(() => _capabilities = value ?? const {});
  }

  void _onEvent(Object? raw) {
    if (!mounted || raw is! Map) return;
    final event = Map<String, Object?>.from(raw);
    final type = event['type'] as String? ?? 'unknown';
    final text = event['text'] as String?;
    setState(() {
      _status = switch (type) {
        'ready' => '듣는 중',
        'speechStart' => '음성 감지',
        'speechEnd' => '결과 처리 중',
        'partial' => '부분 결과',
        'final' => '최종 결과',
        'modelProgress' => '모델 다운로드 ${event['code']}%',
        'modelReady' => 'ko-KR 모델 준비 완료',
        'modelScheduled' => 'ko-KR 모델 다운로드 예약됨',
        'modelRequested' => 'ko-KR 모델 다운로드 요청됨',
        'rms' => '입력 음량 ${event['text']}',
        'error' => event['error'] as String? ?? '오류',
        _ => type,
      };
      if (text != null) _transcript = text;
      final detail = text ?? event['error'] ?? '';
      final code = event['code'] == null ? '' : ' (${event['code']})';
      _log.insert(0, '${event['timestampMs']}  $type$code  $detail');
    });
  }

  void _onStreamError(Object error) {
    if (mounted) setState(() => _status = '브리지 오류: $error');
  }

  Future<void> _checkSupport() async {
    try {
      final support = await _methods.invokeMapMethod<String, Object?>(
        'checkSupport',
      );
      if (!mounted) return;
      setState(() {
        _status = '언어 지원 확인 완료';
        _log.insert(0, '지원 정보: $support');
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? error.code);
    }
  }

  Future<void> _invoke(String method) async {
    try {
      await _methods.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _status = error.message ?? error.code);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _invoke('cancel');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _invoke('cancel');
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Android STT 스파이크')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('상태: $_status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'API ${_capabilities['sdk'] ?? '-'} · ko-KR · 온디바이스 ${_capabilities['onDeviceAvailable'] == true ? '사용 가능' : '사용 불가'}',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _invoke('start'),
                child: const Text('인식 시작'),
              ),
              OutlinedButton(
                onPressed: () => _invoke('stop'),
                child: const Text('인식 종료'),
              ),
              OutlinedButton(
                onPressed: _checkSupport,
                child: const Text('ko-KR 지원 확인'),
              ),
              OutlinedButton(
                onPressed: () => _invoke('downloadModel'),
                child: const Text('모델 다운로드 요청'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('전사 결과'),
          const SizedBox(height: 8),
          SelectableText(
            _transcript.isEmpty ? '직접 만든 문장을 읽어 주세요.' : _transcript,
          ),
          const Divider(height: 32),
          const Text('이벤트 로그'),
          const SizedBox(height: 8),
          for (final item in _log) Text(item),
        ],
      ),
    );
  }
}
