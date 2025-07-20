#!/bin/bash

# SVG 아이콘 생성 스크립트
# ImageMagick이나 기본 시스템 아이콘을 사용하여 아이콘 생성

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ICON_DIR="$PROJECT_ROOT/icons"

echo "크롤러 에이전트 아이콘 생성 중..."

# 아이콘 디렉토리 생성
mkdir -p "$ICON_DIR"

# 크롤러 에이전트 메인 아이콘 생성 (SVG)
cat > "$ICON_DIR/crawler-agent.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4a90e2;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#2563eb;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- 배경 원 -->
  <circle cx="24" cy="24" r="22" fill="url(#grad1)" stroke="#1e40af" stroke-width="2"/>
  
  <!-- 스파이더 몸체 -->
  <ellipse cx="24" cy="24" rx="8" ry="6" fill="#ffffff"/>
  
  <!-- 스파이더 다리들 -->
  <line x1="16" y1="20" x2="8" y2="16" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  <line x1="16" y1="24" x2="6" y2="24" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  <line x1="16" y1="28" x2="8" y2="32" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  
  <line x1="32" y1="20" x2="40" y2="16" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="24" x2="42" y2="24" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  <line x1="32" y1="28" x2="40" y2="32" stroke="#ffffff" stroke-width="2" stroke-linecap="round"/>
  
  <!-- 눈 -->
  <circle cx="20" cy="22" r="1.5" fill="#1e40af"/>
  <circle cx="28" cy="22" r="1.5" fill="#1e40af"/>
  
  <!-- 웹 패턴 -->
  <path d="M12 12 L36 12 L36 36 L12 36 Z" fill="none" stroke="#e5e7eb" stroke-width="0.5" opacity="0.6"/>
  <path d="M12 18 L36 18 M18 12 L18 36 M24 12 L24 36 M30 12 L30 36" stroke="#e5e7eb" stroke-width="0.5" opacity="0.4"/>
</svg>
EOF

# PNG 버전도 생성 (시스템에 convert가 있는 경우)
if command -v convert &> /dev/null; then
    echo "ImageMagick을 사용하여 PNG 아이콘 생성 중..."
    convert "$ICON_DIR/crawler-agent.svg" -resize 48x48 "$ICON_DIR/crawler-agent-48.png"
    convert "$ICON_DIR/crawler-agent.svg" -resize 32x32 "$ICON_DIR/crawler-agent-32.png"
    convert "$ICON_DIR/crawler-agent.svg" -resize 24x24 "$ICON_DIR/crawler-agent-24.png"
    convert "$ICON_DIR/crawler-agent.svg" -resize 16x16 "$ICON_DIR/crawler-agent-16.png"
else
    echo "ImageMagick이 설치되지 않아 PNG 변환을 건너뜁니다."
fi

echo "✓ 아이콘 생성 완료: $ICON_DIR/"
echo "  - crawler-agent.svg (메인 아이콘)"
if [ -f "$ICON_DIR/crawler-agent-48.png" ]; then
    echo "  - crawler-agent-{16,24,32,48}.png (다양한 크기)"
fi