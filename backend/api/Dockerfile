# ใช้ node:22 ตรงกับเวอร์ชันที่ CI (.github/workflows/ci.yml) ทดสอบไว้
# ใช้ตัว -bookworm-slim (glibc) ไม่ใช่ alpine เพราะ argon2 มี prebuilt binary
# สำหรับ glibc เสถียรกว่า ถ้าใช้ alpine (musl) เสี่ยง build native module พังตอน npm ci

FROM node:22-bookworm-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ---- production dependencies ----
FROM node:22-bookworm-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- runtime stage ----
# Lab 07: เปลี่ยนจาก node:22-bookworm-slim เป็น distroless เพราะ Trivy พบช่องโหว่ HIGH/CRITICAL
# 64 จุดใน image เดิม ทั้งหมดมาจากโปรแกรมระบบของ Debian (gzip, mount, ncurses ฯลฯ) และ npm
# ที่ติดมากับ base image ไม่ใช่จากโค้ดของเรา distroless มีแค่ Node.js + glibc ไม่มี shell,
# npm หรือ package manager ใด ๆ ช่องโหว่ลดลงและผู้บุกรุกใช้เครื่องมือในนั้นต่อไม่ได้
# TEST (Lab 07 รอบ B): ใช้ base image เดิมที่มีช่องโหว่ชั่วคราว เพื่อดูว่า Trivy บล็อกได้จริง
FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

EXPOSE 3000

# entrypoint ของ distroless คือ node อยู่แล้ว จึงส่งแค่ไฟล์ที่จะรัน
# ไม่มี shell ให้ใช้ HEALTHCHECK แบบเดิมได้ Kubernetes ตรวจสุขภาพผ่าน readinessProbe แทน
CMD ["node", "dist/main.js"]
