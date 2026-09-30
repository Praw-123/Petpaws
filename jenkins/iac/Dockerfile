# Lab 08: เครื่องมือ IaC ทั้งหมดใน image เดียว ใช้เป็น docker agent ของ pipeline infra
# build ครั้งเดียวในเครื่อง (docker build -t petpaws-iac:1 jenkins/iac) ไม่ต้องดาวน์โหลดใหม่ทุก build
# เพราะเน็ตในแลปหลุดบ่อย ถ้าให้แต่ละ stage ดึง image/ติดตั้งเอง build จะพังแบบสุ่ม
FROM python:3.12-slim-bookworm

ARG TERRAFORM_VERSION=1.9.8
ARG TFSEC_VERSION=1.28.11

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip git openssh-client ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/tf.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
 && unzip /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip \
 && curl -fsSL -o /usr/local/bin/tfsec \
      "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-amd64" \
 && chmod +x /usr/local/bin/tfsec

RUN pip install --no-cache-dir ansible-core==2.17.7 ansible-lint==24.12.2 checkov==3.2.346 awscli==1.36.20

# ansible-lint ต้องมี collection ที่ playbook ใช้ติดตั้งไว้ก่อน
RUN ansible-galaxy collection install community.general community.docker -p /usr/share/ansible/collections
