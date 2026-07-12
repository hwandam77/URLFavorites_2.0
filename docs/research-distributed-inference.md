# Distributed Inference for LLM Classification — Research Report

**작성일**: 2026-04-07  
**대상 프로젝트**: URLFavorites 2.0 (urlf2)  
**목적**: 분산 추론 환경에서의 URL/콘텐츠 분류 및 UI 설계 패턴 조사

---

## 요약

URLFavorites 2.0은 현재 단일 llama-server 노드(`LLAMA_SERVER_URL`)에 의존하는 동기적 LLM 분석 파이프라인을 사용한다. 이 문서는 분산 추론 아키텍처의 주요 패턴, 분류 파이프라인 설계, edge/cloud 트레이드오프, AI 기반 분류 UI/UX 패턴을 정리하고 urlf2에 대한 구체적인 권고안을 제시한다.

---

## 1. 분산 추론 아키텍처 개요

### 1.1 주요 프레임워크 비교

#### vLLM
- **특징**: PagedAttention 메모리 관리 + continuous batching으로 처리량 극대화
- **강점**: 높은 동시 요청 처리 (throughput-first), OpenAI API 호환
- **약점**: GPU 필수, 단일 모델 기준으로 설계됨, 소규모 설정에서 오버헤드 큼
- **적합 시나리오**: 다수 사용자 동시 요청이 있는 SaaS 환경

#### Ray Serve
- **특징**: Python 기반 분산 서빙 레이어, 모델 파이프라인 조합 가능
- **강점**: 멀티 모델 앙상블, 동적 스케일링, 상태 관리, A/B 테스트
- **약점**: 운영 복잡도 높음, 소규모 단일 사용자 환경에서는 과잉
- **적합 시나리오**: 분류 → 태깅 → 요약의 멀티스텝 파이프라인 조합

#### NVIDIA Triton Inference Server
- **특징**: 다중 프레임워크(PyTorch, ONNX, TensorRT) 지원 + 모델 앙상블
- **강점**: GPU 활용률 극대화, dynamic batching, 모델 버전 관리
- **약점**: 설정 복잡, 엔터프라이즈 용도 최적화
- **적합 시나리오**: GPU 클러스터 환경, 고성능 이미지/텍스트 분류

#### Ollama (단일 노드 / 클러스터)
- **특징**: llama.cpp 기반 로컬 LLM 서빙, 매우 낮은 운영 복잡도
- **강점**: 설치 단순, CPU 추론 가능, Apple Silicon 최적화, REST API 기본 제공
- **약점**: 동시 요청 처리 제한적, 클러스터링 지원 미완성
- **적합 시나리오**: 개인 서버 / 홈랩 / 소규모 단일 사용자 서비스 — **urlf2와 유사**

#### llama-server (llama.cpp)
- **특징**: urlf2가 현재 사용 중, OpenAI Chat Completions API 호환
- **강점**: 경량, CPU/GPU 모두 지원, 설정 최소
- **약점**: 동시 요청 처리 제한, 워커 수 고정, 분산 미지원
- **적합 시나리오**: 단일 노드 개인 서비스 (현재 urlf2 수준)

---

### 1.2 분산 추론 패턴 분류

```
[단순 ──────────────────────────────── 복잡]

단일 노드       복수 인스턴스      다중 모델         분산 클러스터
llama-server    Round-robin LB     모델 라우터        Ray/vLLM 클러스터
(현재 urlf2)    + health check     (크기/비용별)      + 오케스트레이션
```

#### 패턴 1: 단일 노드 (현재 urlf2)
```
Solid Queue Job → LlmAnalyzer → llama-server (단일)
```
- 장점: 운영 단순, 디버깅 쉬움
- 단점: 단일 장애점, 병렬 처리 제한

#### 패턴 2: 복수 인스턴스 + 로드밸런서
```
Solid Queue Job → HTTP LB (nginx/haproxy)
                     ├── llama-server:8080
                     ├── llama-server:8081
                     └── llama-server:8082
```
- 장점: 수평 확장 가능, 단순 구성
- 단점: 상태 공유 없음, 모델 메모리 중복

#### 패턴 3: 모델 라우터 (태스크별 전문화)
```
Solid Queue Job → ModelRouter
                     ├── 경량 모델 (태깅, 분류) → Qwen3-7B
                     └── 고품질 모델 (요약, 분석) → Qwen3-30B
```
- 장점: 비용/속도/품질 균형 최적화
- 단점: 라우팅 로직 복잡도 증가

#### 패턴 4: 스트리밍 파이프라인
```
URL 저장 → 스크래핑 Job → [빠른 분류 Job] → [상세 분석 Job] → [인덱싱 Job]
          (즉시)           (수초, 경량 모델)   (수십초, 대형 모델)  (완료 후)
```
- 장점: 사용자에게 단계적 결과 제공 가능
- 단점: 상태 관리 복잡, 재시도 로직 설계 필요

---

## 2. URL/콘텐츠 분류 파이프라인 설계 패턴

### 2.1 분류 태스크 분해

URL 북마크 분류는 단일 태스크가 아니라 여러 서브태스크의 조합이다:

| 태스크 | 입력 | 출력 | 필요 모델 크기 |
|--------|------|------|----------------|
| 콘텐츠 타입 감지 | URL, 도메인, HTML | 웹페이지/YouTube/PDF | 규칙 기반 or 소형 |
| 언어 감지 | 본문 텍스트 | 언어 코드 | 경량 분류기 |
| 토픽 분류 | 제목 + 본문 일부 | 카테고리 태그 | 소형~중형 LLM |
| 요약 생성 | 전체 본문 | 2-3문장 요약 | 중형~대형 LLM |
| 키포인트 추출 | 전체 본문 | 5~10개 포인트 | 중형 LLM |
| 감성 분석 | 본문 | positive/neutral/negative | 소형 모델 |

**현재 urlf2**: 위 모든 태스크를 단일 LLM 호출 1회로 처리 (llm_analyzer.rb)

### 2.2 Two-Stage 분류 패턴

```
Stage 1 (Fast Path, < 2초)
  입력: URL + 제목 + 첫 200자
  모델: 경량 (7B, quantized)
  출력: 태그 초안 3-5개, 콘텐츠 타입
  목적: 즉시 카드에 표시 가능한 메타데이터

Stage 2 (Deep Path, 비동기, 10-60초)
  입력: 전체 본문
  모델: 고품질 (30B+)
  출력: 상세 요약, 키포인트, 정제된 태그
  목적: 상세 페이지 품질 데이터
```

### 2.3 캐싱과 재사용 전략

```ruby
# 현재 urlf2 패턴 (raw_content 저장으로 재분석 가능)
favorite.analysis.update!(raw_content: raw_content, ...)

# 권장 확장: 분류 결과 버전 관리
analysis.update!(
  raw_content:     raw_content,
  model_used:      "qwen3-30b",
  analyzed_at:     Time.current,
  analysis_version: "v2"
)
```

### 2.4 Prompt 설계 패턴

**현재 urlf2 문제점**: 단일 프롬프트에 모든 출력 요청
```ruby
# 현재: 단일 메시지로 모든 필드 요청
{ role: "user", content: "#{type}: #{content}" }
```

**권장: 구조화된 시스템 프롬프트 분리**
```ruby
messages: [
  {
    role: "system",
    content: <<~PROMPT
      You are a content classifier for a personal bookmark manager.
      Analyze the given content and respond with valid JSON only:
      {
        "summary": "2-3 sentence summary",
        "key_points": ["point1", "point2", ...],
        "tags": ["tag1", "tag2", ...],
        "sentiment": "positive|neutral|negative"
      }
      Rules:
      - tags: 3-7 lowercase English words
      - summary: under 200 chars
      - key_points: max 5 items
    PROMPT
  },
  { role: "user", content: content }
]
```

---

## 3. Edge vs Cloud 추론 트레이드오프 (개인 앱 관점)

### 3.1 비교 매트릭스

| 항목 | Edge (로컬/홈서버) | Cloud API |
|------|-------------------|-----------|
| 비용 | 전기 + 하드웨어 (일회성) | 토큰당 과금 |
| 지연 | LAN 내 < 1초 응답 시작 | 네트워크 RTT 추가 |
| 프라이버시 | 완전 로컬, 데이터 외부 전송 없음 | 콘텐츠 API 전송 |
| 모델 품질 | 하드웨어 제약 | GPT-4o, Claude 등 최고 품질 |
| 가용성 | 서버 다운 시 중단 | 99.9% SLA |
| 운영 | 직접 관리 필요 | 관리 불필요 |
| 확장성 | 제한적 | 무제한 |

### 3.2 개인 앱에서의 Edge 추론 적합성

urlf2는 **개인 전용 서비스**로 다음 특성을 가진다:
- 동시 사용자: 1명
- 하루 저장 건수: 수십 건 (피크 아님)
- 데이터 프라이버시 중요 (개인 북마크)
- 이미 Nexus 서버(10.10.0.3) 보유: Qwen3-30B, Qwen3-48B

**결론**: Edge(홈서버) 추론이 urlf2에 최적. Cloud API는 fallback 또는 품질 비교용.

### 3.3 하이브리드 전략

```
우선순위:
1. Nexus LLM (WireGuard VPN, 가장 빠르고 무료)
2. 로컬 llama-server (VPN 불가 시 fallback)
3. Cloud API (둘 다 불가 시 최후 fallback, 선택적)
```

```ruby
# LlmAnalyzer 확장 예시
class LlmAnalyzer
  BACKENDS = [
    { url: ENV["NEXUS_LLM_URL"], model: "qwen3-30b", timeout: 60 },
    { url: ENV["LLAMA_SERVER_URL"], model: "local", timeout: 120 },
  ].freeze

  def self.call(content, type:)
    BACKENDS.each do |backend|
      next unless backend[:url].present?
      result = attempt_call(backend, content, type)
      return result if result
    rescue ServerError => e
      Rails.logger.warn "[LlmAnalyzer] Backend #{backend[:url]} failed: #{e.message}"
    end
    raise ServerError, "All backends failed"
  end
end
```

---

## 4. AI 기반 분류 인터페이스 UI/UX 패턴

### 4.1 분석 상태 표시 패턴

#### 패턴 A: Progressive Disclosure (단계적 공개)
```
저장 직후:    [제목] [도메인]           ← 즉시 표시
수초 후:      + [태그 초안]             ← Fast Path 결과
수십초 후:    + [요약] [키포인트]        ← Deep Path 결과
```
urlf2 현재 구현: `status: pending → analyzing → done` 상태 기반
권장: Hotwire Turbo Stream으로 상태 변화 시 카드 자동 업데이트

#### 패턴 B: Skeleton Loading
```html
<!-- 분석 중 카드 -->
<div class="card animate-pulse">
  <div class="h-4 bg-gray-200 rounded w-3/4"></div>  <!-- 제목 -->
  <div class="h-3 bg-gray-200 rounded w-1/2 mt-2"></div>  <!-- 요약 자리 -->
  <div class="flex gap-1 mt-2">
    <div class="h-5 w-12 bg-gray-200 rounded-full"></div>  <!-- 태그 자리 -->
    <div class="h-5 w-16 bg-gray-200 rounded-full"></div>
  </div>
</div>
```

#### 패턴 C: 분석 실패 상태 명확화
```
[실패 아이콘] "분석 실패 — 재시도" [버튼]
```
현재 urlf2에 구현 필요: `status: "failed"` 시 사용자 액션 제공

### 4.2 AI 태그 인터페이스 패턴

#### AI 태그 vs 사용자 태그 시각적 구분
```
[AI] #technology  [AI] #rails     ← AI 생성, 아이콘으로 구분
[사용자] #읽을것   [사용자] #중요  ← 사용자 추가, 다른 스타일
```

#### 태그 편집 인터랙션
```
클릭: AI 태그 → 컨펌/삭제 선택
인라인 입력: 태그 추가 필드 (엔터로 추가)
드래그: 태그 순서 변경 (옵션)
```

#### 태그 추천 UI
```
사용자가 태그 입력 시:
[#tech] [#programming] [#rails]  ← AI 추천 태그 chip
```

### 4.3 재분석 (Re-analysis) UX

```
상세 페이지 우측 상단:
[재분석] 버튼 → 확인 모달 → Job 큐 → 상태 변화 표시

모달 내용:
"이 항목을 다시 분석합니다.
 기존 AI 요약과 태그가 대체됩니다.
 사용자 메모는 유지됩니다."
```

### 4.4 분류 품질 피드백 루프

#### Thumbs Up/Down 패턴
```
[AI 요약 영역]
"이 요약이 도움이 되었나요?" [👍] [👎]
```
- 피드백 데이터를 로컬 DB에 저장
- 추후 프롬프트 개선 또는 모델 선택 조정에 활용

#### 태그 교정 신호
```
사용자가 AI 태그를 삭제 → 해당 태그 패턴 기록
사용자가 태그를 추가 → 누락 패턴 기록
```

### 4.5 컬렉션 자동 추천 UI

```
AI 분석 완료 후:
"이 항목을 다음 컬렉션에 추가할까요?"
[AI 리서치] [개발 도구]  ← 기존 컬렉션 중 연관성 높은 것 추천
[건너뛰기]  [추가]
```
구현 전략: 태그 겹침 + 키워드 유사도로 경량 추천 (임베딩 불필요)

---

## 5. URLFavorites 2.0 아키텍처 진화 권고안

### 5.1 단기 권고 (현재 Phase 10 완료 후 즉시 적용 가능)

#### 5.1.1 LlmAnalyzer 멀티 백엔드 지원
```ruby
# config/application.rb 또는 환경변수
LLM_BACKENDS = [
  { url: "http://10.10.0.3:8081", model: "qwen3-30b" },  # Nexus 30B
  { url: ENV["LLAMA_SERVER_URL"],  model: "local" }        # 로컬 fallback
]
```

#### 5.1.2 시스템 프롬프트 분리
- 현재: `"#{type}: #{content}"` 단일 user 메시지
- 개선: system 프롬프트에 출력 스펙 명시, user 메시지는 콘텐츠만

#### 5.1.3 Hotwire Turbo Stream 분석 상태 실시간 반영
```ruby
# AnalyzeWebpageJob 완료 후
Turbo::StreamsChannel.broadcast_replace_to(
  "favorite_#{favorite.id}",
  target: "favorite_card_#{favorite.id}",
  partial: "favorites/favorite_card",
  locals: { favorite: favorite }
)
```

#### 5.1.4 재분석 흐름 명확화
- `POST /favorites/:id/reanalyze` 엔드포인트
- raw_content 재사용 (스크래핑 재시도 옵션 포함)
- 상세 페이지에서 재분석 버튼 + 상태 표시

### 5.2 중기 권고 (확장이 필요할 때)

#### 5.2.1 Two-Stage 분류 도입
```
Stage 1: AnalyzeMetadataJob (빠른 분류)
  - 입력: 제목 + URL + 첫 500자
  - 모델: 경량 (Nexus 30B)
  - 목표 시간: < 5초
  - 결과: 태그 초안, 콘텐츠 타입 확인

Stage 2: AnalyzeContentJob (상세 분석)
  - 입력: 전체 raw_content
  - 모델: 고품질 (Nexus 48B)
  - 목표 시간: < 60초
  - 결과: 요약, 키포인트, 정제 태그
```

#### 5.2.2 태그 정규화 모델 도입
```ruby
# 현재: analyses.tags (JSON array, 비정규화)
# 권장: Tag 모델 분리 (검색 강화)
class Tag < ApplicationRecord
  has_many :favorite_tags
  has_many :favorites, through: :favorite_tags
end
```

#### 5.2.3 임베딩 기반 유사 콘텐츠 추천
```
저장 시 → 임베딩 생성 (sentence-transformers, 경량)
         → SQLite vec 확장 저장
         → "유사한 항목" 사이드바 표시
```
구현 옵션: sqlite-vec (Ruby gem 지원), pgvector (PostgreSQL 전환 시)

### 5.3 장기 권고 (사용자 증가 또는 기능 확장 시)

#### 5.3.1 Ray Serve 기반 멀티 모델 파이프라인
```
분류 요청 → Ray Serve Router
             ├── FastClassifier (ONNX, CPU)  → 태그, 언어
             ├── SummaryModel (Qwen-30B)     → 요약, 키포인트
             └── EmbeddingModel (all-MiniLM) → 벡터 저장
```

#### 5.3.2 Knowledge Graph 확장
```
Tag → Topic Graph → 연관 태그 자동 확장
Favorite → 지식 네트워크 시각화
```

#### 5.3.3 개인화 분류 모델 파인튜닝
```
사용자 피드백 누적 → LoRA 파인튜닝
                    → 개인화된 분류 모델
```

---

## 6. 구현 우선순위 매트릭스

| 권고안 | 복잡도 | 효과 | 우선순위 |
|--------|--------|------|---------|
| 시스템 프롬프트 분리 | 낮음 | 분류 품질 향상 | **즉시** |
| Nexus LLM fallback 연결 | 낮음 | 성능 + 안정성 향상 | **즉시** |
| Turbo Stream 상태 업데이트 | 낮음 | UX 향상 | **즉시** |
| 재분석 엔드포인트 명확화 | 낮음 | 기능 완성 | **단기** |
| Two-Stage 분류 | 중간 | 응답성 크게 향상 | **중기** |
| 태그 정규화 모델 | 중간 | 검색 품질 향상 | **중기** |
| 임베딩 유사도 추천 | 높음 | 재발견 경험 강화 | **장기** |
| Ray Serve 파이프라인 | 높음 | 확장성 | **장기** |

---

## 7. 결론

URLFavorites 2.0의 현재 단일 노드 아키텍처(`llama-server` + `Solid Queue`)는 개인 전용 서비스 수준에서 적절하다. 단, 다음 세 가지 개선이 품질과 사용성을 즉시 높일 수 있다:

1. **시스템 프롬프트 구조화** — 분류 품질과 일관성 향상
2. **Nexus 멀티 백엔드 연결** — 이미 보유한 하드웨어 활용 극대화
3. **Hotwire Turbo Stream 실시간 상태** — 분석 중 UX 크게 개선

분산 추론(Ray, vLLM, Triton)은 urlf2의 현재 규모(단일 사용자, 수십 건/일)에서는 명백한 오버엔지니어링이다. Nexus 서버의 두 LLM 슬롯(30B, 48B)을 활용하는 간단한 멀티 백엔드 패턴이 복잡한 분산 프레임워크 없이 동일한 효과를 제공한다.

---

*이 문서는 local-deep-research MCP + 프로젝트 코드베이스 분석을 기반으로 작성되었습니다.*  
*검색 엔진 한계(PubMed 인덱스)로 인해 주요 내용은 분야 전문 지식과 현재 코드베이스 분석으로 보완되었습니다.*
