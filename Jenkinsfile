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
        // ปกติทั้ง pipeline ใช้ราว 4-5 นาที 25 นาทีจึงเผื่อพอสำหรับรอบที่ช้า (รวมเวลารอ Quality Gate)
        timeout(time: 25, unit: 'MINUTES')
    }

    stages {
        // Lab 06: ตรวจความปลอดภัยตามลำดับ Secrets -> SAST -> SCA -> SBOM -> Policy Gate
        // ทั้งหมดอยู่ก่อน Build & Test เพื่อให้โค้ดที่มีปัญหาถูกหยุดตั้งแต่ต้น (shift-left)
        stage('Security') {
            stages {
                stage('Secrets Detection') {
                    agent {
                        docker {
                            image 'zricethezav/gitleaks:v8.21.2'
                            label 'linux-build'
                            args '--entrypoint='
                            reuseNode true
                        }
                    }
                    environment {
                        // git config --global ต้องเขียนไฟล์ใน HOME ซึ่งใน container นี้เขียนไม่ได้
                        HOME = "${WORKSPACE}"
                    }
                    steps {
                        script { env.LAST_STAGE = env.STAGE_NAME }
                        // สแกนทุก commit ในประวัติ ไม่ใช่แค่โค้ดล่าสุด เพราะความลับที่ลบไปแล้วยังค้างใน git
                        // .gitleaksignore ยกเว้น 2 จุดที่ตรวจแล้วว่าไม่ใช่ความลับจริง (ดูเหตุผลในไฟล์)
                        // safe.directory: workspace เป็นของ uid อื่น git จะไม่ยอมอ่านถ้าไม่ประกาศ
                        sh '''
                            mkdir -p reports
                            git config --global --add safe.directory "$WORKSPACE"
                            gitleaks detect --source . --redact --no-banner \
                              --report-format json --report-path reports/gitleaks.json
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'reports/gitleaks.json', allowEmptyArchive: true
                        }
                    }
                }
                stage('SAST - ESLint') {
                    agent {
                        docker {
                            image 'node:22-alpine'
                            label 'linux-build'
                            reuseNode true
                        }
                    }
                    environment {
                        npm_config_cache = "${WORKSPACE}/.npm"
                    }
                    steps {
                        script { env.LAST_STAGE = env.STAGE_NAME }
                        dir('backend/api') {
                            sh 'npm ci'
                            // บล็อกเฉพาะระดับ error ส่วน warning (เช่น detect-object-injection ที่เป็นการค้นตาราง
                            // คำแปลที่เขียนไว้เอง) ให้ผ่านแต่เก็บรายงานไว้ดู
                            sh 'npx eslint -c eslint.security.config.mjs --format json -o ../../reports/eslint-security.json src'
                            sh 'npx eslint -c eslint.security.config.mjs src'
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'reports/eslint-security.json', allowEmptyArchive: true
                        }
                    }
                }
                stage('SAST - Semgrep') {
                    agent {
                        docker {
                            image 'semgrep/semgrep:1.99.0'
                            label 'linux-build'
                            args '--entrypoint='
                            reuseNode true
                        }
                    }
                    environment {
                        HOME = "${WORKSPACE}"
                    }
                    steps {
                        script { env.LAST_STAGE = env.STAGE_NAME }
                        // ใช้กฎ p/owasp-top-ten และ p/nodejs ที่ดาวน์โหลดเก็บไว้ใน security/semgrep/
                        // เพราะเน็ตในห้องแลปหาชื่อ semgrep.dev ไม่เจอเป็นระยะ ทำให้ build ล้มแบบสุ่ม
                        // --error: มี finding เมื่อไหร่ให้ stage ล้ม
                        sh '''
                            semgrep scan --metrics=off --disable-version-check --error \
                              --config security/semgrep/owasp-top-ten.yml \
                              --config security/semgrep/nodejs.yml \
                              --sarif --output reports/semgrep.sarif \
                              backend/api/src
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'reports/semgrep.sarif', allowEmptyArchive: true
                        }
                    }
                }
                stage('SCA - npm audit') {
                    agent {
                        docker {
                            image 'node:22-alpine'
                            label 'linux-build'
                            reuseNode true
                        }
                    }
                    environment {
                        npm_config_cache = "${WORKSPACE}/.npm"
                    }
                    steps {
                        script {
                            env.LAST_STAGE = env.STAGE_NAME
                            // --omit=dev: สแกนเฉพาะ dependency ที่ขึ้นโปรดักชัน เครื่องมือฝั่งพัฒนาไม่ได้รันบนเซิร์ฟเวอร์
                            // npm audit คืน exit code 1 เมื่อพบช่องโหว่ จึงใส่ || true แล้วตัดสินจากตัวเลขใน JSON เอง
                            // ลองใหม่สูงสุด 3 ครั้ง เพราะ audit ต้องถามเซิร์ฟเวอร์ของ npm ซึ่งเน็ตในแลปหลุดเป็นระยะ
                            // ถ้ายังไม่ได้ผล (ไม่มี metadata ใน JSON) ให้หยุด: ไม่รู้ผลการตรวจ = ถือว่าไม่ผ่าน
                            sh '''
                                cd backend/api
                                for i in 1 2 3; do
                                  npm audit --omit=dev --json > ../../reports/audit.json || true
                                  grep -q '"metadata"' ../../reports/audit.json && exit 0
                                  echo "npm audit could not reach the registry (attempt $i), retrying..."
                                  sleep 5
                                done
                                echo "npm audit failed 3 times, cannot verify dependencies"
                                exit 1
                            '''
                            // คู่มือใช้ jq แต่ image node:22-alpine ไม่มี jq จึงอ่าน JSON ด้วย node แทน
                            def count = { String level ->
                                sh(script: "node -p \"require('./reports/audit.json').metadata.vulnerabilities.${level}\"",
                                   returnStdout: true).trim().toInteger()
                            }
                            def critical = count('critical')
                            def high = count('high')
                            echo "npm audit: critical=${critical}, high=${high}"
                            if (high > 0) {
                                unstable("WARN: ${high} high vulnerabilities (allowed, please plan an update)")
                            }
                            // stage นี้ขึ้นแดงเมื่อพบ critical แต่ปล่อยให้ SBOM กับ Policy Gate ทำงานต่อ เพื่อให้ได้ SBOM
                            // ของ build ที่มีปัญหาไว้ตรวจสอบ และให้ Policy Gate เป็นจุดเดียวที่ตัดสินหยุด pipeline
                            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                                if (critical > 0) {
                                    error("Blocking: ${critical} critical vulnerabilities found")
                                }
                                echo 'SCA passed with 0 critical vulnerabilities (warnings allowed)'
                            }
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'reports/audit.json', allowEmptyArchive: true
                        }
                    }
                }
                stage('Generate SBOM') {
                    agent {
                        docker {
                            image 'anchore/syft:v1.18.1-debug'
                            label 'linux-build'
                            args '--entrypoint='
                            reuseNode true
                        }
                    }
                    steps {
                        script { env.LAST_STAGE = env.STAGE_NAME }
                        // อ่านรายการ dependency จาก package-lock.json ไม่ต้องสแกน node_modules ทั้งโฟลเดอร์
                        sh '''
                            /syft scan dir:backend/api --exclude './node_modules/**' \
                              -o cyclonedx-json=reports/sbom.cdx.json
                        '''
                    }
                }
                stage('Sign SBOM') {
                    agent {
                        docker {
                            image 'gcr.io/projectsigstore/cosign:v2.4.1-dev'
                            label 'linux-build'
                            args '--entrypoint='
                            reuseNode true
                        }
                    }
                    environment {
                        COSIGN_PASSWORD = credentials('cosign-password')
                    }
                    steps {
                        script { env.LAST_STAGE = env.STAGE_NAME }
                        // --tlog-upload=false: ลงนามแบบออฟไลน์ ไม่ส่งไปบันทึกที่ Rekor (บริการสาธารณะของ Sigstore)
                        // จากนั้นตรวจลายเซ็นด้วย public key ใน repo ทันที เพื่อยืนยันว่าลายเซ็นใช้ได้จริง
                        withCredentials([file(credentialsId: 'cosign-key', variable: 'COSIGN_KEY')]) {
                            sh '''
                                /ko-app/cosign sign-blob --yes --key "$COSIGN_KEY" --tlog-upload=false \
                                  --output-signature reports/sbom.cdx.json.sig reports/sbom.cdx.json
                                /ko-app/cosign verify-blob --key security/cosign.pub --insecure-ignore-tlog=true \
                                  --signature reports/sbom.cdx.json.sig reports/sbom.cdx.json
                            '''
                        }
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'reports/sbom.cdx.json, reports/sbom.cdx.json.sig', allowEmptyArchive: true
                        }
                    }
                }
                stage('Policy Gate') {
                    agent {
                        docker {
                            image 'openpolicyagent/opa:0.70.0-debug'
                            label 'linux-build'
                            args '--entrypoint='
                            reuseNode true
                        }
                    }
                    steps {
                        script {
                            env.LAST_STAGE = env.STAGE_NAME
                            // พิมพ์ผลการตัดสินทั้งหมด (allow / deny / warn) ไว้ใน console log
                            sh '/opa eval -d policy/security.rego -i reports/audit.json --format pretty data.petpaws.security'
                            // --fail-defined: ถ้ามีข้อ deny แม้แต่ข้อเดียว opa คืน exit code 1 -> หยุด pipeline
                            def rc = sh(script: "/opa eval -d policy/security.rego -i reports/audit.json --fail-defined 'data.petpaws.security.deny[_]' > /dev/null",
                                        returnStatus: true)
                            if (rc != 0) {
                                error('Policy Gate: blocked by policy/security.rego')
                            }
                            echo 'Policy Gate: allowed by policy/security.rego'
                        }
                    }
                }
            }
        }

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

        stage('E2E') {
            // agent linux-build โดยตรง (ไม่ใช่ใน container) เพราะต้องสั่ง docker เปิดฐานข้อมูลชั่วคราวเอง
            agent { label 'linux-build' }
            environment {
                // เทสเป็นแบบ API (ยิง HTTP ใส่ backend) ไม่ต้องใช้เบราว์เซอร์ คู่มือใช้ image
                // mcr.microsoft.com/playwright แต่ Docker บนเน็ตมหาวิทยาลัยดึงจาก mcr ไม่ได้ (EOF)
                // จึงใช้ Node จาก Docker Hub แทน ถ้าดึงได้แล้วเปลี่ยนเป็น mcr.microsoft.com/playwright:v1.63.0-noble
                E2E_IMAGE = 'node:22-bookworm-slim'
                npm_config_cache = "${WORKSPACE}/.npm"
                HOME = "${WORKSPACE}"
                // ค่าสำหรับ backend ชั่วคราวใน e2e เท่านั้น ไม่ใช่ของจริง
                DATABASE_URL = 'postgresql://petpaws:e2e@petpaws-e2e-db:5432/petpaws'
                JWT_ACCESS_SECRET = 'e2e-access'
                JWT_REFRESH_SECRET = 'e2e-refresh'
                JWT_ACCESS_TTL = '15m'
                JWT_REFRESH_TTL = '1d'
                API_PORT = '3000'
                CORS_ORIGIN = '*'
                S3_ENDPOINT = 'http://petpaws-e2e-minio:9000'
                S3_REGION = 'ap-southeast-1'
                S3_BUCKET = 'petpaws-media'
                S3_ACCESS_KEY_ID = 'e2e'
                S3_SECRET_ACCESS_KEY = 'e2e-secret-123'
                S3_FORCE_PATH_STYLE = 'true'
                S3_UPLOAD_URL_TTL = '900'
            }
            steps {
                script { env.LAST_STAGE = env.STAGE_NAME }
                // คู่มือใช้ docker compose up -d แต่ compose mount ไฟล์ด้วย path ของเครื่อง ซึ่ง path ใน
                // agent container ไม่มีอยู่จริงบนเครื่อง จึงใช้ docker cp ส่ง migration เข้าไปแทน
                // backend ต้องมี Postgres (ข้อมูล) กับ MinIO (ตอนเริ่มระบบต้องสร้าง bucket) ส่วน Redis ไม่ใช้
                sh '''
                    docker rm -f petpaws-e2e-db petpaws-e2e-minio >/dev/null 2>&1 || true
                    docker create --name petpaws-e2e-db --network jenkins \
                      -e POSTGRES_USER=petpaws -e POSTGRES_PASSWORD=e2e -e POSTGRES_DB=petpaws \
                      postgres:16-alpine
                    docker cp backend/db/migrations/. petpaws-e2e-db:/docker-entrypoint-initdb.d/
                    docker start petpaws-e2e-db
                    docker run -d --name petpaws-e2e-minio --network jenkins \
                      -e MINIO_ROOT_USER=e2e -e MINIO_ROOT_PASSWORD=e2e-secret-123 \
                      quay.io/minio/minio:latest server /data
                    until docker logs petpaws-e2e-db 2>&1 | grep -q "PostgreSQL init process complete"; do sleep 2; done
                    until docker exec petpaws-e2e-db pg_isready -h 127.0.0.1 -U petpaws; do sleep 1; done
                '''
                script {
                    docker.image(env.E2E_IMAGE).inside('--network jenkins') {
                        // เปิด backend ใน step เดียวกับเทส ให้ปิดพร้อมกันเมื่อ step จบ
                        sh '''
                            cd backend/api
                            npm ci
                            npm run build
                            node dist/main.js > api.log 2>&1 &
                            API_PID=$!
                            for i in $(seq 1 60); do
                              node -e "fetch('http://localhost:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" && break
                              sleep 1
                            done
                            cd ../../e2e
                            npm ci
                            set +e
                            npx playwright test
                            RC=$?
                            kill $API_PID
                            exit $RC
                        '''
                    }
                }
            }
            post {
                always {
                    junit testResults: 'e2e/results/junit.xml', allowEmptyResults: true
                    archiveArtifacts artifacts: 'e2e/playwright-report/**, backend/api/api.log', allowEmptyArchive: true
                    sh 'docker rm -f petpaws-e2e-db petpaws-e2e-minio >/dev/null 2>&1 || true'
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
