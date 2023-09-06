FROM node:18-alpine AS base

# Step 1. Rebuild the source code only when needed
# 빌드할때 실행 되는 Dockerfile
FROM base AS builder

# image 안의 작업 디렉터리 설정 ( cd /app 과 같음)
WORKDIR /app

# Install dependencies based on the preferred package manager
# 현재 폴더(next-front)에 있는 package.json yarn.lock* package-lock.json* pnpm-lock.yaml*을
# WORKDIR 즉 /app 으로 복사
# ==============================package.json==============================
# 자신의 프로젝트가 의존하는 패키지의 리스트
# 자신의 프로젝트의 버전을 명시
# 다른 환경에서도 빌드를 재생 가능하게 만들어, 다른 개발자가 쉽게 사용할 수 있도록 한다.
# ========================================================================
# ===========================package-lock.json============================
# package.json에서는 버전정보를 저장할 때 version range를 사용한다.
# 해당 모듈이 깔릴때 version range 때문에 다른 버전이 깔릴 수 있다.
# package.json에는 틸드(~)로 명시되어있는 모듈들이 package-lock.json에는 버전명이 정확히 명시되어있다.
# package-lock.json이 존재할 때에는 package.json을 사용하여 node_modules를 생성하지않고
# package-lock.json을 사용하여 node_modules를 생성된다.
# ========================================================================
# ===========================yarn.lock============================
# package-lock.json과 동일한 기능을 한다.
# npm install이 아닌 yarn 명령어로 패키지를 설치할때 사용
# ========================================================================

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

# Omit --production flag for TypeScript devDependencies
# 위에서 카피한 package.json yarn.lock* package-lock.json* pnpm-lock.yaml*등등이 있으면
# 다음 명령어를 실행함
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i; \
  # Allow install without lockfile, so example works even without Node.js installed locally
  else echo "Warning: Lockfile not found. It is recommended to commit lockfiles to version control." && yarn install; \
  fi

# LOCAL 파일을 image에 복사
COPY src ./src
COPY public ./public
COPY next.config.js .
COPY tsconfig.json .

# Environment variables must be present at build time
# https://github.com/vercel/next.js/discussions/14030
ARG ENV_VARIABLE
ENV ENV_VARIABLE=${ENV_VARIABLE}
ARG NEXT_PUBLIC_ENV_VARIABLE
ENV NEXT_PUBLIC_ENV_VARIABLE=${NEXT_PUBLIC_ENV_VARIABLE}

# Next.js collects completely anonymous telemetry data about general usage. Learn more here: https://nextjs.org/telemetry
# Uncomment the following line to disable telemetry at build time
# ENV NEXT_TELEMETRY_DISABLED 1

# Build Next.js based on the preferred package manager
RUN \
  if [ -f yarn.lock ]; then yarn build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then pnpm build; \
  else yarn build; \
  fi

# Note: It is not necessary to add an intermediate step that does a full copy of `node_modules` here

# Step 2. Production image, copy all the files and run next
# 실행할때 실행 되는 Dockerfile
FROM base AS runner

WORKDIR /app

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
USER nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Environment variables must be redefined at run time
ARG ENV_VARIABLE
ENV ENV_VARIABLE=${ENV_VARIABLE}
ARG NEXT_PUBLIC_ENV_VARIABLE
ENV NEXT_PUBLIC_ENV_VARIABLE=${NEXT_PUBLIC_ENV_VARIABLE}

# Uncomment the following line to disable telemetry at run time
# ENV NEXT_TELEMETRY_DISABLED 1

# Note: Don't expose ports here, Compose will handle that for us

CMD ["node", "server.js"]
