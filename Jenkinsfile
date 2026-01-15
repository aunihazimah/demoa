// Top-level variables (must be outside pipeline)
def CONTAINER_NAME = "myapi-container"
def IMAGE_NAME     = "myapi-img:${BUILD_NUMBER}"
def NETWORK_NAME   = "jenkins-net"
def SERVICE_PORT   = "8290"

pipeline {
    agent any

    environment {
        // API metadata
        API_NAME    = "AppointmentAPI"
        API_VERSION = "1.0.0"

        // WSO2
        PUBLISHER_URL = "https://wso2am:9443"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aunihazimah/demoa.git',
                    credentialsId: 'github-token'
            }
        }

        stage('Create Docker Network') {
            steps {
                sh """
                  docker network inspect ${NETWORK_NAME} >/dev/null 2>&1 || \
                  docker network create ${NETWORK_NAME}
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('Deploy API Container') {
            steps {
                sh """
                  docker stop ${CONTAINER_NAME} || true
                  docker rm ${CONTAINER_NAME} || true
                  docker run -d \
                    --name ${CONTAINER_NAME} \
                    --network ${NETWORK_NAME} \
                    -p ${SERVICE_PORT}:${SERVICE_PORT} \
                    ${IMAGE_NAME}
                """
                sleep 20
            }
        }

        stage('Wait for WSO2 API Manager') {
            steps {
                timeout(time: 3, unit: 'MINUTES') {
                    waitUntil {
                        def status = sh(
                            script: "curl -k -s -o /dev/null -w '%{http_code}' ${PUBLISHER_URL}/api/am/publisher/v4/apis",
                            returnStdout: true
                        ).trim()

                        echo "WSO2 HTTP Status: ${status}"
                        return status == '401' || status == '200'
                    }
                }
            }
        }

        stage('Request OAuth Token') {
            steps {
                withCredentials([
                    string(credentialsId: 'wso2-client-id', variable: 'CLIENT_ID'),
                    string(credentialsId: 'wso2-api-token', variable: 'CLIENT_SECRET')
                ]) {
                    script {
                        def response = sh(
                            script: """
                              curl -k -s -X POST ${PUBLISHER_URL}/oauth2/token \
                                -H "Content-Type: application/x-www-form-urlencoded" \
                                -u "${CLIENT_ID}:${CLIENT_SECRET}" \
                                -d "grant_type=client_credentials"
                            """,
                            returnStdout: true
                        ).trim()

                        def json = new groovy.json.JsonSlurperClassic().parseText(response)
                        env.WSO2_ACCESS_TOKEN = json.access_token

                        echo "OAuth token acquired"
                    }
                }
            }
        }

        stage('Verify Backend API') {
            steps {
                sh "curl -s http://localhost:${SERVICE_PORT}/appointmentservices/getAppointment"
            }
        }
    }

    post {
        always {
            sh """
              docker stop ${CONTAINER_NAME} || true
              docker rm ${CONTAINER_NAME} || true
            """
            cleanWs()
        }
    }
}
