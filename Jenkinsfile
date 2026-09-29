pipeline {
    // Lab 05: แยก agent ราย stage แทน agent เดียวทั้ง pipeline เพราะ stage ต่าง ๆ ใช้ image ต่างกัน
    // (node สำหรับ build/test, sonar-scanner สำหรับวิเคราะห์โค้ด) ส่วน Quality Gate แค่รอผลจาก
    // SonarQube ไม่ต้องจอง executor ของ linux-build ซึ่งมีแค่ช่องเดียว
    agent none

    environment {
        APP_NAME = 'petpaws-api'
        NODE_ENV = 'test'
    }

    options {
        // ทุก stage ต้องมีเวลาจำกัด: executor ของ linux-build มีแค่ 1 ช่อง ถ้า npm ci ค้างเพราะเน็ตหลุด
        // หรือเทสไม่ยอมจบ (เช่นมี connection ค้างอยู่) build จะยึด executor ไว้ตลอดไป งานอื่นทั้งคิวจะรอไม่มีที่สิ้นสุด
        // และไม่มีใครรู้ว่าพัง timeout จะยกเลิก build ปล่อย executor คืน และขึ้นสถานะให้เห็น
        // ปกติทั้ง pipeline ใช้ราว 2-3 นาที 15 นาทีจึงเผื่อพอสำหรับรอบที่ช้า (รวมเวลารอ Quality Gate)
        timeout(time: 15, unit: 'MINUTES')
    }

    stages {
        stage('Build & Test') {
            // รันใน container node:22-alpine บน agent linux-build (agent ตัวเดียวที่สั่ง docker ได้)
            // คู่มือใช้ node:20-alpine แต่ backend ของ PetPaws ต้องใช้ Node 22: dependency บางตัวกำหนด
            // engine >= 22 และบน Node 20 + alpine แพ็กเกจ argon2 ไม่มีไฟล์สำเร็จรูป ต้องคอมไพล์เอง
            agent {
                docker {
                    image 'node:22-alpine'
                    label 'linux-build'
                }
            }
            environment {
                // container รันด้วย uid ของ agent ซึ่งเขียนลง HOME ไม่ได้ ให้ npm เก็บ cache ใน workspace แทน
                npm_config_cache = "${WORKSPACE}/.npm"
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
                            // คู่มือใช้ Jest + jest-junit แต่โปรเจกต์นี้ใช้ Vitest ซึ่งมี reporter แบบ JUnit ในตัว
                            // coverage ออกทั้ง cobertura (ให้ Jenkins) และ lcov (ให้ SonarQube) ดู vitest.config.ts
                            sh 'npx vitest run --coverage --reporter=default --reporter=junit --outputFile.junit=reports/junit.xml'
                        }
                    }
                }
            }
            post {
                always {
                    junit testResults: 'backend/api/reports/junit.xml', allowEmptyResults: true
                    // publishCoverage ในคู่มือถูกเลิกใช้แล้ว Coverage plugin ตัวใหม่ใช้ recordCoverage แทน
                    recordCoverage tools: [[parser: 'COBERTURA', pattern: 'backend/api/coverage/cobertura-coverage.xml']],
                        sourceDirectories: [[path: 'backend/api']]
                    // npm 10 ไม่สร้าง npm-debug.log ในโฟลเดอร์งานแล้ว แต่เขียน log ไว้ใน cache/_logs แทน
                    archiveArtifacts artifacts: 'backend/api/npm-debug.log*, .npm/_logs/*.log', allowEmptyArchive: true
                }
            }
        }

        stage('SonarQube Analysis') {
            agent {
                docker {
                    image 'sonarsource/sonar-scanner-cli:5'
                    label 'linux-build'
                    // ต้องอยู่ network เดียวกับ SonarQube ถึงจะเรียก http://sonarqube:9000 ได้
                    // และล้าง entrypoint ของ image ไม่งั้นมันจะรัน sonar-scanner ทันทีแทนที่จะรอคำสั่ง
                    args '--network jenkins --entrypoint='
                    reuseNode true
                }
            }
            environment {
                SONAR_USER_HOME = "${WORKSPACE}/.sonar"
            }
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                withSonarQubeEnv('SonarQube') {
                    dir('backend/api') {
                        // coverage.exclusions ตรงกับ exclude ใน vitest.config.ts: วัด coverage เฉพาะ logic
                        // ที่ unit test ได้ ส่วน controller/service/module ที่ต้องต่อ DB จริงไม่นับ
                        sh '''
                            sonar-scanner \
                              -Dsonar.projectKey=petpaws-api \
                              -Dsonar.projectName=petpaws-api \
                              -Dsonar.sources=src \
                              -Dsonar.tests=src \
                              -Dsonar.exclusions=**/*.spec.ts \
                              -Dsonar.test.inclusions=**/*.spec.ts \
                              -Dsonar.coverage.exclusions=**/*.controller.ts,**/*.service.ts,**/*.module.ts,**/*.guard.ts,**/*.strategy.ts,**/*.decorator.ts,**/*.filter.ts,**/*.gateway.ts,**/*.processor.ts,**/dto/**,src/config/**,src/main.ts \
                              -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                // รอ SonarQube ส่ง webhook กลับมาบอกผล ถ้าไม่ผ่าน (coverage < 70%) ให้หยุด pipeline ทันที
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // Lab 04: branch strategy feature -> develop -> main
        // develop = staging ปล่อยอัตโนมัติ, main = production ต้องมีคนกดอนุมัติก่อน
        stage('Deploy — Staging') {
            when { branch 'develop' }
            agent { label 'linux-build' }
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                sh 'echo deploying to staging...'
            }
        }
        stage('Deploy — Production') {
            // beforeInput / beforeAgent: เช็ค branch ก่อนถามอนุมัติและก่อนจอง agent
            // ไม่งั้น Jenkins จะหยุดถาม input ในทุก branch ก่อน แล้วค่อยข้าม stage ทีหลัง
            when {
                beforeInput true
                beforeAgent true
                branch 'main'
            }
            input {
                message 'Deploy to production?'
            }
            agent { label 'linux-build' }
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
    }
}
