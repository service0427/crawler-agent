#!/bin/bash

# 허브 연결 설정 스크립트
# 이 파일은 설치 시 자동으로 실행되어 허브 설정을 적용합니다

# 프로덕션 허브 설정
export PROD_HUB_URL="https://mkt.techb.kr:8443"
export PROD_HUB_IPS="mkt.techb.kr,220.78.239.115"

# 허브 시크릿은 별도로 관리
# 설치 시 자동으로 다운로드되거나 환경변수로 전달