pipeline {
    agent any

    options {
        timestamps()
    }

    environment {
        PYTHON_EXE = 'C:\\Python313\\python.exe'
        FLUTTER_EXE = 'C:\\src\\flutter\\bin\\flutter.bat'
        CI = 'true'
    }

    stages {
        stage('Preparar reportes') {
            steps {
                dir('.ci-reports') {
                    deleteDir()
                }
            }
        }

        stage('Preparar entorno Python') {
            steps {
                bat '"%PYTHON_EXE%" -m venv .ci-venv'
                bat '".ci-venv\\Scripts\\python.exe" -m pip install -r backend\\UniTest\\requirements-test.txt'
            }
        }

        stage('Pruebas backend') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    bat 'if not exist .ci-reports\\backend mkdir .ci-reports\\backend'
                    dir('backend/UniTest') {
                        bat '"%WORKSPACE%\\.ci-venv\\Scripts\\python.exe" -m pytest -p no:cacheprovider --junitxml="%WORKSPACE%\\.ci-reports\\backend\\resultados.xml" --html="%WORKSPACE%\\.ci-reports\\backend\\index.html" --self-contained-html --cov --cov-config=.coveragerc --cov-report="html:%WORKSPACE%\\.ci-reports\\backend\\cobertura"'
                    }
                }
            }
        }

        stage('Preparar Flutter') {
            steps {
                dir('frontend') {
                    bat 'call "%FLUTTER_EXE%" pub get'
                }
            }
        }

        stage('Pruebas frontend') {
            steps {
                dir('frontend') {
                    bat 'call "%FLUTTER_EXE%" test --no-pub'
                }
            }
        }
    }

    post {
        always {
            script {
                if (fileExists('.ci-reports/backend/resultados.xml')) {
                    junit testResults: '.ci-reports/backend/resultados.xml'
                }
                if (fileExists('.ci-reports/backend/index.html')) {
                    publishHTML(target: [
                        reportDir: '.ci-reports/backend',
                        reportFiles: 'index.html',
                        reportName: 'Pruebas backend',
                        keepAll: true,
                        alwaysLinkToLastBuild: false,
                        allowMissing: false
                    ])
                }
                if (fileExists('.ci-reports/backend/cobertura/index.html')) {
                    publishHTML(target: [
                        reportDir: '.ci-reports/backend/cobertura',
                        reportFiles: 'index.html',
                        reportName: 'Cobertura backend',
                        keepAll: true,
                        alwaysLinkToLastBuild: false,
                        allowMissing: false
                    ])
                }
                archiveArtifacts artifacts: '.ci-reports/backend/**', allowEmptyArchive: true
            }
        }
    }
}
