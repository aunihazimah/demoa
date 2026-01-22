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
        API_CONTEXT = "/appointment"

        // WSO2 URLs
        AM_HOST        = "wso2am"
        PUBLISHER_URL  = "https://${AM_HOST}:9443"
        GATEWAY_URL    = "https://${AM_HOST}:8243"
        ADMIN_URL      = "https://${AM_HOST}:9443"

        APP_NAME = "ci-cd-app"
    }

    stages {

        stage('Checkout SCM') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/aunihazimah/demoa.git',
                    credentialsId: 'github-token'
            }
        }

        stage('Docker Network') {
            steps {
                sh """
                  docker network inspect ${NETWORK_NAME} >/dev/null 2>&1 || \
                  docker network create ${NETWORK_NAME}
                """
            }
        }

        stage('Build & Deploy Backend') {
            steps {
                sh """
                  docker build -t ${IMAGE_NAME} .
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

        // ---------- PUBLISHER ----------
        stage('Get Publisher Token') {
            steps {
                withCredentials([
                    string(credentialsId: 'wso2-client-id', variable: 'CLIENT_ID'),
                    string(credentialsId: 'wso2-client-secret', variable: 'CLIENT_SECRET')
                ]) {
                    script {
                        env.PUBLISHER_TOKEN = sh(
                            script: """
                              curl -k -s -u $CLIENT_ID:$CLIENT_SECRET \
                              -d grant_type=client_credentials \
                              ${PUBLISHER_URL}/oauth2/token \
                              | sed -n 's/.*"access_token":"\\([^"]*\\)".*/\\1/p'
                            """,
                            returnStdout: true
                        ).trim()
                    }
                }
            }
        }

        stage('Import & Publish API') {
            steps {
                script {
                    sh """
                      curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/import-openapi \
                        -H "Authorization: Bearer ${PUBLISHER_TOKEN}" \
                        -F "file=@openapi.yaml" \
                        -F "overwriteAPI=true" \
                        -F "additionalProperties={
                          \\"name\\":\\"${API_NAME}\\",
                          \\"context\\":\\"${API_CONTEXT}\\",
                          \\"version\\":\\"${API_VERSION}\\",
                          \\"endpointConfig\\":{
                            \\"endpoint_type\\":\\"http\\",
                            \\"sandbox_endpoints\\":{
                              \\"url\\":\\"http://${CONTAINER_NAME}:${SERVICE_PORT}\\"
                            }
                          }
                        }"
                    """

                    env.API_ID = sh(
                        script: """
                          curl -k -s -H "Authorization: Bearer ${PUBLISHER_TOKEN}" \
                          "${PUBLISHER_URL}/api/am/publisher/v4/apis?query=name:${API_NAME} version:${API_VERSION}" \
                          | sed -n 's/.*"id":"\\([^"]*\\)".*/\\1/p'
                        """,
                        returnStdout: true
                    ).trim()

                    sh """
                      curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/change-lifecycle \
                        -H "Authorization: Bearer ${PUBLISHER_TOKEN}" \
                        -H "Content-Type: application/json" \
                        -d '{"action":"Publish","apiId":"${API_ID}"}'
                    """
                }
            }
        }

        // ---------- ADMIN API ----------
        stage('Create Application (Admin API)') {
            steps {
                script {
                    env.APP_ID = sh(
                        script: """
                          curl -k -s -X POST ${ADMIN_URL}/api/am/admin/v4/applications \
                          -H "Authorization: Bearer ${PUBLISHER_TOKEN}" \
                          -H "Content-Type: application/json" \
                          -d '{
                            "name":"${APP_NAME}",
                            "throttlingPolicy":"Unlimited",
                            "tokenType":"OAUTH"
                          }' | sed -n 's/.*"applicationId":"\\([^"]*\\)".*/\\1/p'
                        """,
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Generate App Token') {
            steps {
                script {
                    env.APP_TOKEN = sh(
                        script: """
                          curl -k -s -X POST ${ADMIN_URL}/api/am/admin/v4/applications/${APP_ID}/generate-keys \
                          -H "Authorization: Bearer ${PUBLISHER_TOKEN}" \
                          -H "Content-Type: application/json" \
                          -d '{"keyType":"PRODUCTION","grantTypes":["client_credentials"]}'
                          | sed -n 's/.*"accessToken":"\\([^"]*\\)".*/\\1/p'
                        """,
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Smoke Test via Gateway') {
            steps {
                sh """
                  curl -k -f \
                  -H "Authorization: Bearer ${APP_TOKEN}" \
                  ${GATEWAY_URL}${API_CONTEXT}/${API_VERSION}/appointmentservices/getAppointment
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}
