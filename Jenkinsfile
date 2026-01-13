pipeline{
    agent any

    environment{
        //Docker container & image configuration
        CONTAINER_NAME = "myapi-container"
        IMAGE_NAME     = "myapi-img:${BUILD_NUMBER}"
        NETWORK_NAME   = "jenkins-net"
        SERVICE_PORT   = "8290"

        //API metadata
        API_NAME       = "AppointmentAPI"
        API_VERSION    = "1.0.0"
        API_CONTEXT    = "/appointment"
        API_RESOURCE   = "/appointmentservices/getAppointment"

        //WSO2 endpoints
        PUBLISHER_URL  = "https://localhost:9443"
        GATEWAY_URL    = "https://localhost:8243"

        // WSO2 access token stored securely in Jenkins credentials
        WSO2_TOKEN     = credentials('wso2-api-token')
    }

    stages{
        stage('Checkout SCM') {
            steps {
                // Pull latest source code from Git repository
                checkout scm
            }
        }

        stage('Create Docker Network') {
            steps {
                // Ensure Docker network exists
                sh """
                docker network inspect ${NETWORK_NAME} >/dev/null 2>&1 || \
                docker network create ${NETWORK_NAME}
                """
            }
        }

        stage('Build Docker Image') {
            steps {
                // Build Docker image containing the API service
                sh "docker build -t ${IMAGE_NAME} ."
            }
        }

        stage('Deploy API Container') {
            steps {
                // Stop and remove old container (if any)
                // Deploy new container using the latest image
                sh """
                docker stop ${CONTAINER_NAME} || true
                docker rm ${CONTAINER_NAME} || true

                docker run -d \
                  --name ${CONTAINER_NAME} \
                  --network ${NETWORK_NAME} \
                  -p ${SERVICE_PORT}:${SERVICE_PORT} \
                  ${IMAGE_NAME}
                """
                // Give the API time to fully start
                sleep 40
            }
        }

        stage('Verify Backend API') {
            steps {
                // Health check: verify API is reachable directly (without gateway)
                // Fail pipeline if API does not respond successfully
                sh """
                curl -f http://${CONTAINER_NAME}:${SERVICE_PORT}${API_RESOURCE}
                """
            }
        }

        stage('Register / Update API in WSO2') {
            steps {
                // Import or update API in WSO2 Publisher using OpenAPI definition
                // This automates API creation instead of manual UI work
                sh """
                curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/import-openapi \
                  -H "Authorization: Bearer ${WSO2_TOKEN}" \
                  -F "file=@openapi.yaml" \
                  -F "additionalProperties={ \\
                      \\"name\\":\\"${API_NAME}\\", \\
                      \\"context\\":\\"${API_CONTEXT}\\", \\
                      \\"version\\":\\"${API_VERSION}\\", \\
                      \\"endpointConfig\\":{ \\
                        \\"endpoint_type\\":\\"http\\", \\
                        \\"sandbox_endpoints\\":{ \\
                          \\"url\\":\\"http://${CONTAINER_NAME}:${SERVICE_PORT}\\" \\
                        } \\
                      } \\
                  }"
                """
            }
        }

        stage('Publish API to Gateway') {
            steps {
                // Change API lifecycle state to PUBLISHED
                // Makes API available through WSO2 Gateway
                sh """
                curl -k -X POST ${PUBLISHER_URL}/api/am/publisher/v4/apis/change-lifecycle \
                  -H "Authorization: Bearer ${WSO2_TOKEN}" \
                  -H "Content-Type: application/json" \
                  -d '{
                        "action": "Publish",
                        "apiId": "'"${API_NAME}:${API_VERSION}"'"
                      }'
                """
            }
        }

        stage('Smoke Test via API Gateway') {
            steps {
                // Final validation: test API via Gateway URL
                // Confirms external clients can access the API
                sh """
                curl -k -f \
                ${GATEWAY_URL}${API_CONTEXT}/${API_VERSION}${API_RESOURCE}
                """
            }
        }

    }

    post{
        always {
            // Cleanup: remove running container and Jenkins workspace
            sh """
            docker stop ${CONTAINER_NAME} || true
            docker rm ${CONTAINER_NAME} || true
            """
            cleanWs()
        }
    }
}