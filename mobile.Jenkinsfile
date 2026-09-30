// Lab 10: pipeline ฝั่ง Mobile (แอป Flutter ที่ root ของ repo) แทน taskflow-mobile ในคู่มือ
// รันบน Kubernetes Pod ชั่วคราวทั้งหมด (dynamic agent) ใช้กับ Multibranch job petpaws-mobile
pipeline {
    agent {
        kubernetes {
            defaultContainer 'flutter'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: flutter
    image: ghcr.io/cirruslabs/flutter:stable
    imagePullPolicy: IfNotPresent
    command: ['cat']
    tty: true
    resources:
      requests: { memory: "3Gi" }
  - name: jnlp
    image: jenkins/inbound-agent:latest-jdk21
    imagePullPolicy: IfNotPresent
'''
        }
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        skipDefaultCheckout(true)
    }

    environment {
        // cache ของ Flutter/Gradle อยู่ใน workspace ของ Pod (Pod ใหม่ทุก build จึงไม่ค้าง)
        PUB_CACHE = "${WORKSPACE}/.pub-cache"
        GRADLE_USER_HOME = "${WORKSPACE}/.gradle-home"
    }

    stages {
        stage('Checkout') {
            steps {
                container('jnlp') {
                    retry(3) {
                        checkout scm
                    }
                }
                sh 'git config --global --add safe.directory "$WORKSPACE" || true'
                sh 'flutter --version'
                retry(3) {
                    sh 'flutter pub get --enforce-lockfile'
                }
            }
        }

        // ขั้นที่ไม่ขึ้นต่อกันรันขนานใน Pod เดียวกัน
        stage('Verify') {
            parallel {
                stage('Analyze') {
                    steps {
                        sh 'flutter analyze --no-fatal-infos'
                    }
                }
                stage('Test + Coverage') {
                    steps {
                        sh 'flutter test --coverage'
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'coverage/lcov.info', allowEmptyArchive: true
                        }
                    }
                }
                stage('SCA - osv-scanner') {
                    steps {
                        // ตรวจช่องโหว่ของแพ็กเกจ Dart จาก pubspec.lock เทียบกับฐานข้อมูล OSV
                        retry(3) {
                            sh '''
                                curl -fsSL -o osv-scanner \
                                  https://github.com/google/osv-scanner/releases/download/v1.9.2/osv-scanner_linux_amd64
                                chmod +x osv-scanner
                            '''
                        }
                        sh './osv-scanner --lockfile=pubspec.lock'
                    }
                }
            }
        }

        stage('Build Debug APK') {
            steps {
                sh 'flutter build apk --debug'
            }
            post {
                success {
                    archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/app-debug.apk'
                }
            }
        }

        // AAB สำหรับขึ้น Play Store ลงนามด้วย keystore จริง ทำเฉพาะ main เท่านั้น
        stage('Build Signed Release AAB') {
            when { branch 'main' }
            steps {
                withCredentials([
                    file(credentialsId: 'android-keystore', variable: 'ANDROID_KEYSTORE_FILE'),
                    string(credentialsId: 'android-keystore-password', variable: 'ANDROID_KEYSTORE_PASSWORD')
                ]) {
                    sh 'flutter build appbundle --release'
                    // ยืนยันว่าลงนามด้วย keystore ของเรา ไม่ใช่ debug key
                    sh '''
                        keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | head -8
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'build/app/outputs/bundle/release/app-release.aab'
                }
            }
        }
    }

    post {
        always {
            script {
                def status = currentBuild.currentResult
                def icon = status == 'SUCCESS' ? ':white_check_mark:' : ':x:'
                def text = "${icon} ${env.JOB_NAME} #${env.BUILD_NUMBER} ${status}\\nbranch: ${env.BRANCH_NAME}\\n${env.BUILD_URL}"
                withCredentials([string(credentialsId: 'slack-webhook', variable: 'SLACK_URL')]) {
                    writeFile file: 'slack.json', text: "{\"text\": \"${text}\"}"
                    sh 'curl -s -X POST -H "Content-Type: application/json" --data @slack.json "$SLACK_URL" || true'
                }
            }
        }
    }
}
