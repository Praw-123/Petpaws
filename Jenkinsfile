pipeline {
    // รัน build ใน container node:22-alpine บน agent linux-build (agent ตัวเดียวที่สั่ง docker ได้)
    // คู่มือใช้ node:20-alpine แต่ backend ของ PetPaws ต้องใช้ Node 22: dependency บางตัวกำหนด
    // engine >= 22 และบน Node 20 + alpine แพ็กเกจ argon2 ไม่มีไฟล์สำเร็จรูป ต้องคอมไพล์เอง
    // ซึ่ง image alpine ไม่มี Python/g++ ให้ ติดตั้งไม่ผ่าน
    agent {
        docker {
            image 'node:22-alpine'
            label 'linux-build'
        }
    }

    environment {
        APP_NAME = 'petpaws-api'
        NODE_ENV = 'test'
        // container รันด้วย uid ของ agent ซึ่งเขียนลง HOME ไม่ได้ ให้ npm เก็บ cache ใน workspace แทน
        npm_config_cache = "${WORKSPACE}/.npm"
    }

    options {
        // ทุก stage ต้องมีเวลาจำกัด: executor ของ linux-build มีแค่ 1 ช่อง ถ้า npm ci ค้างเพราะเน็ตหลุด
        // หรือเทสไม่ยอมจบ (เช่นมี connection ค้างอยู่) build จะยึด executor ไว้ตลอดไป งานอื่นทั้งคิวจะรอไม่มีที่สิ้นสุด
        // และไม่มีใครรู้ว่าพัง timeout จะยกเลิก build ปล่อย executor คืน และขึ้นสถานะให้เห็น
        // ปกติทั้ง pipeline ใช้ราว 1-2 นาที 10 นาทีจึงเผื่อพอสำหรับรอบที่ช้าโดยไม่ปล่อยให้ค้างนานเกินไป
        timeout(time: 10, unit: 'MINUTES')
    }

    stages {
        stage('Install') {
            steps {
                // post ระดับ pipeline ไม่ได้อยู่ใน stage ไหน env.STAGE_NAME ตรงนั้นจึงเป็น null
                // เลยจำชื่อ stage ล่าสุดไว้เอง เพื่อให้ post failure บอกได้ว่าพังที่ stage ไหน
                script { env.LAST_STAGE = env.STAGE_NAME }
                echo "Building ${env.APP_NAME} (NODE_ENV=${env.NODE_ENV})"
                dir('backend/api') {
                    sh 'node --version'
                    sh 'npm ci'
                }
            }
        }
        stage('Lint') {
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                dir('backend/api') {
                    sh 'npm run lint'
                }
            }
        }
        stage('Unit Test') {
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                dir('backend/api') {
                    sh 'npm test'
                }
            }
        }

        // Lab 04: branch strategy feature -> develop -> main
        // develop = staging ปล่อยอัตโนมัติ, main = production ต้องมีคนกดอนุมัติก่อน
        stage('Deploy — Staging') {
            when { branch 'develop' }
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                sh 'echo deploying to staging...'
            }
        }
        stage('Deploy — Production') {
            // beforeInput: เช็ค branch ก่อนถามอนุมัติ ไม่งั้น Jenkins จะหยุดถาม input
            // ในทุก branch ก่อน แล้วค่อยข้าม stage ทีหลัง
            when {
                beforeInput true
                branch 'main'
            }
            input {
                message 'Deploy to production?'
            }
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                sh 'echo deploying to production...'
            }
        }
    }

    post {
        success {
            echo "SUCCESS: ${env.APP_NAME} passed on ${env.NODE_ENV}"
        }
        failure {
            echo "FAILURE: failed at stage: ${env.LAST_STAGE}"
        }
        always {
            // npm 10 ไม่สร้าง npm-debug.log ในโฟลเดอร์งานแล้ว แต่เขียน log ไว้ใน cache/_logs แทน
            archiveArtifacts artifacts: 'backend/api/npm-debug.log*, .npm/_logs/*.log', allowEmptyArchive: true
        }
    }
}
