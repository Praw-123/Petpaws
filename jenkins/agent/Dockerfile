# Agent "linux-build" สำหรับ Lab 01 — inbound-agent เปล่า ๆ ไม่มี Node
# เลยติดตั้ง Node 22 (เวอร์ชันเดียวกับที่ backend ใช้ใน .github/workflows/ci.yml) ไว้ใน image
# libatomic1: Node ที่ NodeJS plugin ดาวน์โหลดมา (Lab 02 tools { nodejs }) รันไม่ได้ถ้าไม่มีไลบรารีนี้
FROM jenkins/inbound-agent:latest-jdk21

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates libatomic1 \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# Lab 03: agent { docker { image 'node:20-alpine' } } ต้องสั่ง docker ได้ เลยใส่แค่ตัว CLI
# แล้วตอนรัน container ค่อย mount /var/run/docker.sock ของเครื่องเข้ามา (ไม่ได้รัน Docker ซ้อนข้างใน)
COPY --from=docker:27-cli /usr/local/bin/docker /usr/local/bin/docker
USER jenkins
