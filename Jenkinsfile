// Top-level variables
def CONTAINER_NAME = "myapi-container"
def IMAGE_NAME     = "myapi-img:${BUILD_NUMBER}"
def NETWORK_NAME   = "jenkins-net"
def SERVICE_PORT   = "8290"

pipeline {
    agent any

    environment {
        // API metadata
        API_NAME     = "AppointmentAPI"
        API_VERSION  = "1.0.0"
        API_CONTEXT  = "/appointment"
        API_RESOURCE = "/appointmentservices/getAppointment"

        // WSO2 endpoints
        PUBLISHER_URL = "https://wso2am:9443"
        GATEWAY_URL   = "https://wso2am:8243"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aunihazimah/demoa.git',
                    credentialsId: 'github-token' // must exist in Jenkins Global credentials
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
                        script {
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
        }

        stage('Get WSO2 OAuth Token') {
            steps {
                withCredentials([
                    string(credentialsId: 'wso2-client-id', variable: 'CLIENT_ID'),
                    string(credentialsId: 'wso2-api-token', variable: 'CLIENT_SECRET')
                ]) {
                    script {
                        env.WSO2_ACCESS_TOKEN = sh(
                            script: """curl -k -s -X POST ${PUBLISHER_URL}/oauth2/token \
                                -H 'Content-Type: application/x-www-form-urlencoded' \
                                -u "$CLIENT_ID:$CLIENT_SECRET" \
                                -d 'grant_type=client_credentials' \
                                | sed -n 's/.*"access_token":"\\\\([^"]*\\\\)".*/\\\\1/p'""",
                            returnStdout: true
                        ).trim()
                        echo "✅ OAuth token acquired"
                    }
                }
            }
        }

        stage('Register / Update API in WSO2') {
            steps {
                script {
                    // Import OpenAPI definition
                    sh """
                        curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/import-openapi \
                            -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                            -F "file=@openapi.yaml" \
                            -F "additionalProperties={ \\"name\\":\\"${API_NAME}\\", \\"context\\":\\"${API_CONTEXT}\\", \\"version\\":\\"${API_VERSION}\\", \\"endpointConfig\\":{ \\"endpoint_type\\":\\"http\\", \\"sandbox_endpoints\\":{ \\"url\\":\\"http://${CONTAINER_NAME}:${SERVICE_PORT}\\" } } }"
                    """

                    // Get API ID dynamically
                    def apiId = sh(
                        script: """curl -k -s -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                            "${PUBLISHER_URL}/api/am/publisher/v4/apis?query=name:${API_NAME}" \
                            | sed -n 's/.*"id":"\\\\([^"]*\\\\)".*/\\\\1/p'""",
                        returnStdout: true
                    ).trim()

                    echo "API ID: ${apiId}"

                    // Publish API
                    sh """
                        curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/change-lifecycle \
                            -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                            -H "Content-Type: application/json" \
                            -d '{"action":"Publish","apiId":"'"${apiId}"'"}'
                    """
                }
            }
        }

        stage('Verify Backend API') {
            steps {
                sh "curl -s http://${CONTAINER_NAME}:${SERVICE_PORT}${API_RESOURCE}"
            }
        }

        stage('Smoke Test via API Gateway') {
            steps {
                sh "curl -k -f http://${CONTAINER_NAME}:${SERVICE_PORT}${API_RESOURCE}"
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
