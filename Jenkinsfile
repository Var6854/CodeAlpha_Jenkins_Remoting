pipeline {
    agent {
        label 'java-agent'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 15, unit: 'MINUTES')
    }

    stages {
        stage('Checkout Source Code') {
            steps {
                echo "=========================================================="
                echo " Stage 1: Checkout Source Code on Agent: ${env.NODE_NAME}"
                echo " Workspace: ${env.WORKSPACE}"
                echo "=========================================================="
                script {
                    if (fileExists('.git')) {
                        echo "Existing git repository found in workspace. Fetching updates..."
                        if (isUnix()) {
                            sh 'git pull origin main || true'
                        } else {
                            bat 'git pull origin main || exit /b 0'
                        }
                    } else {
                        echo "Cloning source code into isolated agent workspace..."
                        if (isUnix()) {
                            sh 'git config --global --add safe.directory "*" && git clone /repo . || git clone file:///repo .'
                        } else {
                            bat 'git clone "C:/Users/Admin1/Documents/GitHub/CodeAlpha_Jenkins_Remoting" .'
                        }
                    }
                }
            }
        }

        stage('Verify Remote Node & Environment') {
            steps {
                echo "=========================================================="
                echo " Distributed Build Execution: Remote Inbound Agent "
                echo " Assigned Node: ${env.NODE_NAME}"
                echo " Node Labels:   ${env.NODE_LABELS}"
                echo " Workspace:     ${env.WORKSPACE}"
                echo " Controller:    ${env.JENKINS_URL}"
                echo " Build ID:      ${env.BUILD_NUMBER}"
                echo "=========================================================="
                script {
                    if (isUnix()) {
                        sh '''
                            echo "=== Agent System Details ==="
                            echo "Hostname: $(hostname)"
                            echo "Kernel / OS: $(uname -s -r -m)"
                            echo "Current User: $(whoami)"
                            echo "Working Directory: $(pwd)"
                            echo "=== Java Environment ==="
                            java -version
                        '''
                    } else {
                        bat '''
                            @echo off
                            echo === Agent System Details ===
                            echo Hostname: %COMPUTERNAME%
                            echo OS: %OS%
                            echo Current User: %USERNAME%
                            echo Working Directory: %CD%
                            echo === Java Environment ===
                            java -version
                        '''
                    }
                }
            }
        }

        stage('Compile Application') {
            steps {
                echo "Compiling Java 21 sources on ${env.NODE_NAME}..."
                script {
                    if (isUnix()) {
                        sh 'chmod +x ./gradlew && ./gradlew compileJava --no-daemon'
                    } else {
                        bat 'set JAVA_OPTS=-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT && gradlew.bat compileJava --no-daemon'
                    }
                }
            }
        }

        stage('Run Unit Tests') {
            steps {
                echo "Executing JUnit 5 test suite on remote agent..."
                script {
                    if (isUnix()) {
                        sh './gradlew test --no-daemon'
                    } else {
                        bat 'set JAVA_OPTS=-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT && gradlew.bat test --no-daemon'
                    }
                }
            }
        }

        stage('Package & Archive Artifact') {
            steps {
                echo "Creating production JAR artifact on ${env.NODE_NAME}..."
                script {
                    if (isUnix()) {
                        sh './gradlew build --no-daemon'
                    } else {
                        bat 'set JAVA_OPTS=-Djavax.net.ssl.trustStoreType=WINDOWS-ROOT && gradlew.bat build --no-daemon'
                    }
                }
                echo "Archiving artifacts and test reports back to Jenkins controller..."
                archiveArtifacts artifacts: 'build/libs/*.jar, build/reports/tests/**', fingerprint: true, allowEmptyArchive: false
            }
        }
    }

    post {
        success {
            echo "SUCCESS: Distributed build and test pipeline finished cleanly on agent [${env.NODE_NAME}]."
        }
        failure {
            echo "FAILURE: Build failed on agent [${env.NODE_NAME}]."
        }
    }
}
