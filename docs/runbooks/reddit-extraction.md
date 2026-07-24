# Reddit 추출 운영 가이드 (rdt-cli)

이 문서는 Rails 앱이 Reddit 게시물을 추출할 때 사용하는 외부 CLI `rdt`의 설치·운영·장애 대응을 다룬다.

## 목적 / 아키텍처

Rails `UrlFavorites::Integrations::Reddit::Extractor` 가 `Open3` 로 외부 명령 `rdt read <post_id> --json` 을 호출해 Reddit 게시물 본문·메타·상위 댓글을 가져온다. `rdt` 자체는 Reddit 인증 쿠키를 로컬 브라우저(`browser-cookie3`)에서 추출해 Reddit JSON API 를 두드리는 Python CLI 다. Rails 는 `rdt` 의 stdout JSON 만 파싱하며 Reddit 인증 상태는 직접 관리하지 않는다.

```
[ URL 입력 ] → Rails Integrations::Reddit::Extractor → Open3 → /Users/.../.local/bin/rdt → Reddit API
                                                                            ↑
                                              ~/.config/rdt-cli/credential.json (쿠키 캐시)
```

`rdt` 가 인증 실패 시 stderr + 비-zero exit code 를 돌려주면 Extractor 는 해당 favorite 을 `failed` 상태로 표시하고 큐 잡은 Solid Queue 가 재시도/포기한다.

## Mac (개발 머신) 설치 절차 — 실측 기반

> **반드시 고정 커밋을 설치한다.** PyPI 의 `rdt-cli` 는 구버전이라 사용 금지.

```bash
# pipx 가 없으면
brew install pipx
pipx ensurepath

# 고정 커밋 설치
pipx install 'git+https://github.com/public-clis/rdt-cli.git@5e4fb3720d5c174e976cd425ccc3b879d52cac66'

# 검증
rdt --version          # → rdt, version 0.4.2
rdt status --json      # → ok:true, authenticated:true, cookie_count>0
```

### 로그인 (Mac 에서 1회)

```bash
rdt login
```

기본 브라우저(Chrome/Safari/Edge/Firefox 지원)를 자동으로 열어 Reddit 쿠키를 `~/.config/rdt-cli/credential.json` 에 저장한다. Chrome 에 Reddit 로그인 세션이 없으면 인증 실패 — 이 경우 **Mac 에서 브라우저에 1회 로그인 후 재시도**.

```bash
# 로그인 상태 확인
rdt status --json
# {
#   "ok": true,
#   "data": {
#     "authenticated": true,
#     "cookie_count": 15,
#     "credential_file": "/Users/hwandam/.config/rdt-cli/credential.json",
#     "source": "browser:subprocess",
#     ...
#   }
# }
```

## bastion (운영 서버) 설치 절차

bastion 은 headless 라 `rdt login` 불가. **Mac 에서 생성한 credential.json 을 그대로 복사**한다.

### 1. pipx + rdt-cli 설치 (bastion 에서)

```bash
ssh bastion

# pipx 가 없으면
sudo apt install -y pipx
pipx ensurepath
# (대안) sudo 없이 --user 설치
python3 -m pip install --user pipx
python3 -m pipx ensurepath --user

# 고정 커밋 설치
pipx install 'git+https://github.com/public-clis/rdt-cli.git@5e4fb3720d5c174e976cd425ccc3b879d52cac66'

# PATH 확인
which rdt
# → /home/hwandam/.local/bin/rdt
```

### 2. credential.json 이관 (Mac → bastion)

Mac 에서:

```bash
# Mac credential 확인
ls -la ~/.config/rdt-cli/credential.json

# bastion 에 scp (소유자 권한 유지 위해 권한 명시)
scp ~/.config/rdt-cli/credential.json bastion:~/.config/rdt-cli/credential.json
```

bastion 에서:

```bash
# 디렉토리·파일 권한 (반드시 600, 다른 사용자 읽기 차단)
mkdir -p ~/.config/rdt-cli
chmod 700 ~/.config/rdt-cli
chmod 600 ~/.config/rdt-cli/credential.json

# 검증
rdt status --json
# → ok:true, authenticated:true 확인
```

### 3. systemd PATH 확인 — ⚠️ 핵심 함정

> **2026-07-24 yt-dlp 이관 장애와 동일 클래스.** pipx 기본 설치 경로인 `/home/hwandam/.local/bin` 은 사용자의 interactive shell PATH 에는 자동 추가되지만, systemd 가 기동하는 Puma 의 `Environment=PATH` 에는 포함되지 않을 수 있다. 미확인 상태면 분석 잡이 `No such file or directory - rdt` 로 실패한다.

확인 절차:

```bash
# 1) Puma 프로세스가 받은 PATH 확인
PID=$(systemctl show rails-puma@urlfavorites_2.0.service -p MainPID --value)
tr '\0' '\n' < /proc/$PID/environ | grep ^PATH=

# 2) PATH 에 /home/hwandam/.local/bin 이 없으면 drop-in 에서 강제 주입
sudo systemctl edit rails-puma@urlfavorites_2.0.service

# --- 아래 내용으로 /etc/systemd/system/rails-puma@urlfavorites_2.0.service.d/override.conf 생성 ---
[Service]
Environment="PATH=/home/hwandam/.local/bin:/usr/local/bin:/usr/bin:/bin"

# 3) 적용
sudo systemctl daemon-reload
sudo systemctl restart rails-puma@urlfavorites_2.0

# 4) 재확인
tr '\0' '\n' < /proc/$(systemctl show rails-puma@urlfavorites_2.0.service -p MainPID --value)/environ | grep ^PATH=
which -a rdt   # PATH 가 /home/hwandam/.local/bin 일 때만 잡힘
```

`yt-dlp` 사례(2026-07-24)에서는 standalone 바이너리를 `/usr/local/bin` 에 풀어 PATH 함정을 우회했다. `rdt` 는 Python 패키지라 standalone 이 없으므로 **PATH 주입이 정공법**이다.

### 4. 고정 (Pinned) 보장

서버에서 `pipx upgrade rdt-cli` 등으로 의도치 않게 업그레이드되지 않도록 메타데이터 확인:

```bash
pipx list --json | python3 -c "import sys,json; d=json.load(sys.stdin)['venvs']['rdt-cli']['metadata']['main_package']; print(d['package_or_url'])"
# → git+https://github.com/public-clis/rdt-cli.git@5e4fb3720d5c174e976cd425ccc3b879d52cac66
# → package_version: 0.4.2
```

## 쿠키 만료 대응

Reddit 세션 쿠키는 **기본 7일** 후 만료된다. 만료 시점부터 모든 Reddit 추출이 실패한다.

### 증상 (식별 패턴)

- Reddit 타입 favorite 만 `failed` 상태로 누적되고 다른 도메인(youtube/text/article)은 정상 분석 완료
- `journalctl -u rails-puma@urlfavorites_2.0` 에 `rdt` 호출 직후 stderr 로 `401 Unauthorized` / `not_found` 류 메시지
- `rdt status --json` 결과가 `authenticated: false` 또는 `cookie_count: 0`

### 갱신 절차

```bash
# 1) Mac 에서 rdt login 으로 쿠키 재추출
rdt login
rdt status --json   # authenticated:true 확인

# 2) bastion 에 credential.json 재복사
scp ~/.config/rdt-cli/credential.json bastion:~/.config/rdt-cli/credential.json

# 3) bastion 에서 권한 재설정 + 검증
ssh bastion
chmod 600 ~/.config/rdt-cli/credential.json
rdt status --json

# 4) Rails 는 credential 파일 mtime 을 자동 감시하지 않으므로 Puma 재시작으로 안전하게 로드
sudo systemctl restart rails-puma@urlfavorites_2.0
```

### 자동 갱신 메모 (선택)

자주 만료되어 부담되면 bastion 에서 5일 주기 cron 으로 `rdt login --headless` 를 시도할 수 있으나, headless 인증은 본질적으로 brittle 하므로 **수동 갱신 + 만료 알람(7일 cron + status 검사)** 조합이 안정적이다.

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `rdt: command not found` (Rails 잡 stderr) | pipx PATH 미설정 또는 systemd PATH 에 `~/.local/bin` 누락 | interactive: `pipx ensurepath` + 새 셸. systemd: 위 §3 PATH 주입 |
| `rdt status` 가 `authenticated:false` | credential.json 없음/만료/권한 오류 | `ls -la ~/.config/rdt-cli/` → 파일 없으면 §2 절차 재실행, 권한 `600` 재설정 |
| Reddit 타입만 `failed` 누적, 다른 도메인 정상 | 쿠키 만료 (위 §쿠키 만료) | Mac 에서 재로그인 → credential 재복사 → Puma 재시작 |
| `No such file or directory - rdt` (Rails 잡 stderr) | systemd PATH 함정 (yt-dlp 사례와 동일 클래스) | `tr '\0' '\n' < /proc/$PID/environ \| grep ^PATH=` → §3 PATH 주입 |
| `ModuleNotFoundError` 또는 `ImportError` | pipx venv 손상 (의존성 mismatch, 시스템 Python 업그레이드 등) | `pipx uninstall rdt-cli && pipx install 'git+https://github.com/public-clis/rdt-cli.git@<commit>'` |
| `pipx install` 이 venv 을 못 만들고 실패 | 기존 venv 디렉토리 손상 | `rm -rf ~/.local/pipx/venvs/rdt-cli && pipx install ...` |
| `permission denied` on credential.json | 권한 600 아님 | `chmod 600 ~/.config/rdt-cli/credential.json` |
| `rdt read <id> --json` 이 `not_found` | post id 형식 오류 (예: `t3_xxx` prefix 포함) | bare id 사용: `rdt read bawfcs` (spec 의 예시) |

## 부록: rdt read 출력 스키마 (실측)

`rdt read <post_id> --json` 출력의 최상위 키 구조 (2026-07-24 실측, rdt-cli 0.4.2):

```json
{
  "ok": true,
  "schema_version": "1",
  "data": {
    "post": {
      "id": "bawfcs",
      "name": "t3_bawfcs",
      "title": "...",
      "subreddit": "AskReddit",
      "author": "...",
      "score": 41634,
      "num_comments": 6864,
      "created_utc": 1554743676.0,
      "permalink": "/r/AskReddit/comments/bawfcs/...",
      "url": "https://www.reddit.com/r/AskReddit/comments/bawfcs/...",
      "selftext": "",
      "is_self": true,
      "over_18": false,
      "is_video": false,
      "stickied": false
    },
    "comments": [
      {
        "id": "ekf5nop",
        "fullname": "t1_ekf5nop",
        "author": "...",
        "body": "...",
        "parent_fullname": "t3_bawfcs",
        "score": 3632,
        "created_utc": 1554758982.0,
        "more_count": 0,
        "more_children": [],
        "replies": [ /* 재귀: 위와 동일 스키마, [more] 플레이스홀더 포함 */ ]
      }
    ],
    "more_count": <int>,
    "more_children": [/* 펼치지 않은 자식 fullname 목록 */]
  }
}
```

에러 응답:

```json
{
  "ok": false,
  "schema_version": "1",
  "error": { "code": "not_found", "message": "Resource not found" }
}
```

전체 샘플: `test/fixtures/files/rdt_read_sample.json` (bawfcs/AskReddit, 12 top-level + 재귀 50 댓글, 1637 more_children, 89KB).

## 참고

- upstream: https://github.com/public-clis/rdt-cli
- 고정 커밋: `5e4fb3720d5c174e976cd425ccc3b879d52cac66` (2026-07-24 시점)
- yt-dlp PATH 함정 사례: 프로젝트 `CLAUDE.md` 트러블슈팅 표
