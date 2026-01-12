# Node.js 20 Alpine 이미지 사용
FROM node:20-alpine

# better-sqlite3 빌드에 필요한 패키지 설치
RUN apk add --no-cache python3 make g++

WORKDIR /app

# 의존성 파일 복사 및 설치
COPY package*.json ./
RUN npm ci --only=production

# 소스 코드 복사
COPY src ./src

# 데이터 디렉토리 생성
RUN mkdir -p /app/data

# 환경 변수
ENV NODE_ENV=production
ENV PORT=3000
ENV DB_PATH=/app/data/secureotp.db

EXPOSE 3000

CMD ["node", "src/index.js"]
