pipeline {
    agent any

    environment {
        // Docker container & image configuration
        CONTAINER_NAME = "myapi-container"
        IMAGE_NAME     = "myapi-img:${BUILD_NUMBER}"
        NETWORK_NAME   = "jenkins-net"
        SERVICE_PORT   = "8290"

        // API metadata
        API_NAME       = "AppointmentAPI"
        API_VERSION    = "1.0.0"
        API_CONTEXT    = "/appointment"
        API_RESOURCE   = "/appointmentservices/getAppointment"

        // WSO2 endpoints
        PUBLISHER_URL  = "https://wso2am:9443"
        GATEWAY_URL    = "https://wso2am:8243"

        // WSO2 Client ID stored in Jenkins (Secret Text)
        WSO2_CLIENT_ID = credentials('wso2-client-id')
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
                script {
                    echo "⏳ Waiting for WSO2 AM to start..."
                    timeout(time: 3, unit: 'MINUTES') {
                        waitUntil {
                            def status = sh(
                                script: "curl -k -s -o /dev/null -w '%{http_code}' ${PUBLISHER_URL}/api/am/publisher/v4/apis",
                                returnStdout: true
                            ).trim()
                            echo "WSO2 HTTP Status: ${status}"
                            return status == '200' || status == '401'
                        }
                    }
                }
            }
        }

        stage('Request WSO2 OAuth2 Token') {
            steps {
                withCredentials([string(credentialsId: 'wso2-api-token', variable: 'WSO2_CLIENT_SECRET')]) {
                    script {
                        env.WSO2_ACCESS_TOKEN = sh(
                            script: """curl -k -s -X POST ${PUBLISHER_URL}/token \
                                -H "Content-Type: application/x-www-form-urlencoded" \
                                -u "${WSO2_CLIENT_ID}:${WSO2_CLIENT_SECRET}" \
                                -d "grant_type=client_credentials" | jq -r '.access_token'""",
                            returnStdout: true
                        ).trim()
                        echo "✅ WSO2 OAuth token obtained"
                    }
                }
            }
        }

        stage('Verify Backend API') {
            steps {
                sh "curl -f http://${CONTAINER_NAME}:${SERVICE_PORT}${API_RESOURCE}"
            }
        }

        stage('Register / Update API in WSO2') {
            steps {
                sh """
                curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/import-openapi \
                    -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                    -F "file=@openapi.yaml" \
                    -F "additionalProperties={ \\"name\\":\\"${API_NAME}\\", \\"context\\":\\"${API_CONTEXT}\\", \\"version\\":\\"${API_VERSION}\\", \\"endpointConfig\\":{ \\"endpoint_type\\":\\"http\\", \\"sandbox_endpoints\\":{ \\"url\\":\\"http://${CONTAINER_NAME}:${SERVICE_PORT}\\" } } }"
                """
            }
        }

        stage('Publish API to Gateway') {
            steps {
                script {
                    // Retrieve API ID dynamically
                    def apiId = sh(
                        script: """curl -k -s -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                            "${PUBLISHER_URL}/api/am/publisher/v4/apis?query=name:${API_NAME}" | jq -r '.list[0].id'""",
                        returnStdout: true
                    ).trim()
                    echo "API ID: ${apiId}"

                    sh """
                    curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/change-lifecycle \
                        -H "Authorization: Bearer ${WSO2_ACCESS_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -d '{"action":"Publish","apiId":"'"${apiId}"'"}'
                    """
                }
            }
        }

        stage('Smoke Test via API Gateway') {
            steps {
                sh "curl -k -f ${GATEWAY_URL}${API_CONTEXT}${API_RESOURCE}"
            }
        }
    }

    post {
        always {
            script {
                sh """
                docker stop ${CONTAINER_NAME} || true
                docker rm ${CONTAINER_NAME} || true
                """
            }
            cleanWs()
        }
    }
}
