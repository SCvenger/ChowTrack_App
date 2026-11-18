pipeline {
    agent any

    tools {
        // Mismas herramientas configuradas para el proyecto Taller QA.
        jdk 'JDK 25'
        maven 'Maven 3.10.0'
    }

    options {
        timestamps()
    }

    environment {
        PYTHON_EXE = 'C:\\Python313\\python.exe'
        FLUTTER_EXE = 'C:\\src\\flutter\\bin\\flutter.bat'
        CI = 'true'
        // Jenkins corre como LocalSystem y el SDK de Flutter pertenece a otro
        // usuario: sin esto Git lo rechaza por "dubious ownership".
        GIT_CONFIG_COUNT = '1'
        GIT_CONFIG_KEY_0 = 'safe.directory'
        GIT_CONFIG_VALUE_0 = 'C:/src/flutter'
    }

    stages {
        stage('Preparar reportes') {
            steps {
                dir('.ci-reports') {
                    deleteDir()
                }
                bat 'if not exist .ci-reports\\backend mkdir .ci-reports\\backend'
                bat 'if not exist .ci-reports\\frontend mkdir .ci-reports\\frontend'
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
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    dir('frontend') {
                        bat 'call "%FLUTTER_EXE%" test --no-pub --file-reporter "json:%WORKSPACE%\\.ci-reports\\frontend\\resultados.json"'
                    }
                }
            }
        }

        stage('Reporte Serenity') {
            steps {
                // Convierte los resultados reales de pytest y flutter al formato
                // de Serenity y genera el reporte con serenity-maven-plugin.
                bat '".ci-venv\\Scripts\\python.exe" qa\\serenity\\resultados_a_serenity.py'
                bat 'mvn -B -f qa\\serenity\\pom.xml verify'
            }
        }
    }

    post {
        always {
            script {
                if (fileExists('.ci-reports/backend/resultados.xml')) {
                    junit testResults: '.ci-reports/backend/resultados.xml'
                }
                if (fileExists('qa/serenity/target/site/serenity/index.html')) {
                    publishHTML(target: [
                        reportDir: 'qa/serenity/target/site/serenity',
                        reportFiles: 'index.html',
                        reportName: 'Serenity Report',
                        keepAll: true,
                        alwaysLinkToLastBuild: true,
                        allowMissing: false
                    ])
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
                archiveArtifacts artifacts: '.ci-reports/**', allowEmptyArchive: true
            }
        }
    }
}
