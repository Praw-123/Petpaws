terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state เก็บใน S3 ของ LocalStack (จำลอง AWS ในเครื่อง) พร้อมตาราง DynamoDB กันรันซ้อน
  # ไม่เก็บ terraform.tfstate ใน git: state มีข้อมูลลับ (เช่น SSH private key) และต้องมีที่เดียว
  # ที่ทุกคนใช้ร่วมกัน ไม่ใช่ไฟล์ที่ต่างคนต่างถือ
  # credential ของ LocalStack ส่งผ่านตัวแปรสภาพแวดล้อม AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  backend "s3" {
    bucket         = "petpaws-tfstate"
    key            = "lab08/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "petpaws-tflock"
    encrypt        = true
    use_path_style = true
    endpoints = {
      s3       = "http://localstack:4566"
      dynamodb = "http://localstack:4566"
    }
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
