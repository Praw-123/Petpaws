# เครื่องจำลอง VM สำหรับ Lab 08: Debian ที่มี SSH กับ Python พร้อมให้ Ansible เข้ามาตั้งค่า
# ของอื่น (Node.js, Docker) ติดตั้งโดย Ansible playbook ไม่ใช่ใน image นี้
FROM debian:12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server python3 ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd /root/.ssh \
 && chmod 700 /root/.ssh \
 && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

EXPOSE 22 8080
CMD ["/usr/sbin/sshd", "-D", "-e"]
