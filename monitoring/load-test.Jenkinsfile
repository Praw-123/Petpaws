// Lab 09: งานทดสอบโหลด ใช้ Pod template "k8s-node" (label k8s-node) ที่ตั้งไว้ใน Kubernetes cloud
// สั่งพร้อมกันหลายงาน ขณะที่ cloud จำกัดไว้ 2 Pod งานที่เหลือต้องรอคิว -> ทำให้ alert ทำงาน
pipeline {
    agent { label 'k8s-node' }
    parameters {
        string(name: 'RUN', defaultValue: '0', description: 'หมายเลขรอบ (กันไม่ให้ Jenkins รวมงานในคิวเป็นงานเดียว)')
    }
    stages {
        stage('Work') {
            steps {
                container('node') {
                    sh 'node --version'
                    sh 'echo "load run $RUN on $(hostname)"; sleep 120'
                }
            }
        }
    }
}
