#!/bin/bash
# Public 저장소에 커밋할 수 없는 파일과 대표적인 시크릿 패턴을 검사한다.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

forbidden_files='\.(p8|p12|mobileprovision|cer|certSigningRequest|keystore)$|(^|/)GoogleService-Info\.plist$|(^|/)\.env($|\.)|Secrets.*\.xcconfig$|secrets.*\.xcconfig$'
tracked_files="$(git ls-files)"
if forbidden_matches="$(printf '%s\n' "$tracked_files" | grep -E "$forbidden_files")"; then
    printf '%s\n' "$forbidden_matches"
    echo "커밋 금지 파일이 추적되고 있다" >&2
    exit 1
elif [ "$?" -gt 1 ]; then
    echo "추적 파일 이름 검사 중 오류가 발생했다" >&2
    exit 1
fi

secret_pattern='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{30,}|xox[baprs]-[A-Za-z0-9-]{10,}'
if secret_matches="$(git grep -n -I -E "$secret_pattern" -- . ':!scripts/check_public_repo.sh')"; then
    printf '%s\n' "$secret_matches"
    echo "시크릿으로 의심되는 문자열이 있다" >&2
    exit 1
elif [ "$?" -gt 1 ]; then
    echo "시크릿 문자열 검사 중 오류가 발생했다" >&2
    exit 1
fi

# 제품 코드와 테스트에는 특정 출처의 본문이나 기본 탑재 콘텐츠를 두지 않는다.
copyright_pattern='성경|불경|찬송가|기도문|경전'
if copyright_matches="$(git grep -n -I -E "$copyright_pattern" -- lib test android ios)"; then
    printf '%s\n' "$copyright_matches"
    echo "제품 또는 테스트 경로에 금지된 제3자 콘텐츠 표지가 있다" >&2
    exit 1
elif [ "$?" -gt 1 ]; then
    echo "제3자 콘텐츠 검사 중 오류가 발생했다" >&2
    exit 1
fi

echo "Public 저장소 정책 검사 통과"
