# Lab 08: สภาพแวดล้อมสำหรับ deploy petpaws-api
#
# ใช้ 2 ส่วนคู่กัน เพราะแลปนี้รันในเครื่องไม่มีบัญชี AWS จริง:
#   1. AWS ผ่าน LocalStack: Security Group เปิดพอร์ต 8080 และ EC2 instance
#      LocalStack รุ่นฟรีจำลอง EC2 ได้แค่ข้อมูล (ได้ ID/IP) แต่ไม่ได้เปิดเครื่องจริงให้ SSH เข้าไป
#   2. Docker container `petpaws-host`: เครื่องจริงที่ Ansible เข้าไปติดตั้งของได้
#      ทำหน้าที่แทน VM ใน cloud (มี SSH, Python) เปิดพอร์ต 8080 ตาม Security Group

provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  endpoints {
    ec2 = var.localstack_endpoint
    sts = var.localstack_endpoint
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

data "aws_vpc" "default" {
  default = true
}

# ---------- AWS (LocalStack) ----------

resource "aws_security_group" "web" {
  name        = "petpaws-web"
  description = "Allow HTTP to petpaws-api on port 8080"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "petpaws-api HTTP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  # detailed monitoring (CloudWatch) ปิดไว้ เพราะ LocalStack รุ่นฟรียังไม่รองรับคำสั่ง MonitorInstances
  monitoring    = false
  ebs_optimized = true

  tags = merge(local.tags, { Name = "petpaws-app" })
}

# ---------- Docker host (เครื่องที่ Ansible ตั้งค่าได้จริง) ----------

resource "tls_private_key" "ansible" {
  algorithm = "ED25519"
}

resource "docker_image" "host" {
  name = "petpaws-host:lab08"
  build {
    context = "${path.module}/../host"
  }
  keep_locally = true
}

resource "docker_container" "host" {
  name     = "petpaws-host"
  image    = docker_image.host.image_id
  hostname = "petpaws-host"

  networks_advanced {
    name = var.docker_network
  }

  # ใช้ Docker ของเครื่องแม่แทนการเปิด Docker daemon ซ้อนข้างใน (ดึง image จาก registry ในเครื่องได้เลย)
  mounts {
    target = "/var/run/docker.sock"
    source = "/var/run/docker.sock"
    type   = "bind"
  }

  upload {
    file    = "/root/.ssh/authorized_keys"
    content = tls_private_key.ansible.public_key_openssh
  }

  labels {
    label = "project"
    value = "petpaws"
  }
}

locals {
  tags = {
    Project   = "petpaws"
    ManagedBy = "terraform"
    Lab       = "08"
  }
}
