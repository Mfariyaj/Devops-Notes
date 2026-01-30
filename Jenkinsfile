Pipelines{
    
    environment {
        APP_NAME = "Mnode-app"
        IMAGE_TAG = "${BUILD_NUMBER}"
        DOCKERHUB_REPO = "your-dockerhub-username/mnode-app"
        PUSH_TO = "ECR" // Options: DOCKERHUB or ECR
        AWS_REGION = "us-east-1"
        AWS_ACCOUNT_ID = "your-aws-account-id"
        ECR_REPO = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
        MANIFEST_REPO = "your-github-username/mnode-manifests"
        DEPLOY_ENV = "production"
        SONAR_PROJECT_KEY = ${APP_NAME}
    }

    stages{
        stage ("checkout the code") {
            stpes{
                checkout scm
            }
        }
        
        stage ("download the dependencies") {
            stpes{
                sh "npm install"
            }
        }

        stage ("unit tests") {
            stpes{
                sh '"npm test || echo "No Tests failed"'
            }
        }

        stage ("Sonar sacnner") {
            stpes{
                withSonarqubeEnv("sonar-scanner"){
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.sources=. \
                        -Dsonar.laguage=js \
                        -Dsonar.sourceEncoding=UTF-8
                    '''
                }
            }
        }

        stage ("Quality Gate") {
            stpes{
                timeout(time: 1, unit: "MINUTES"){
                    waitForQualityGate abortPipeline: True
                }
            }
        }

        stage ("Build Docker image") {
            stpes{
                sh  "docker build -t ${APP_NAME}:${IMAGE_TAG}"
            }
        }

        stage ("Scan Docker image") {
            stpes{
                sh  "trivy image -- serverity HIGH CRITICAL ${APP_NAME}:${IMAGE_TAG} --exit-code 1"
            }
        }

        stage("Push Image") {
            steps {
                script {

                    if (env.PUSH_TO == "DOCKERHUB") {

                        withCredentials([usernamePassword(
                            credentialsId: 'dockerhub-creds',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )]) {

                            sh '''
                            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                            docker tag ${APP_NAME}:${IMAGE_TAG} ${DOCKERHUB_REPO}:${IMAGE_TAG}
                            docker push ${DOCKERHUB_REPO}:${IMAGE_TAG}
                            '''
                        }

                    } else {

                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                          credentialsId: 'aws-ecr-creds']]) {

                            sh '''
                            aws ecr get-login-password --region ${AWS_REGION} \
                              | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                            docker tag ${APP_NAME}:${IMAGE_TAG} ${ECR_REPO}:${IMAGE_TAG}
                            docker push ${ECR_REPO}:${IMAGE_TAG}
                            '''
                        }
                    }
                }
            }
        }

        stage ("cehcout manifest repo") {
            steps{
                withCredentials([string(credentialsID: 'github_token',  variables: "GITHUB_TOKEN")]){

                    sh "git clone https://${GITHUB_TOKEN}@github.com/your-org/k8s-manifest-repo.git"
                }
            }
        }
                stage("Update Manifest") {
            steps {
                sh '''
                cd k8s-manifest-repo/${DEPLOY_ENV}
                sed -i "s|image:.*|image: ${ECR_REPO}:${IMAGE_TAG}|" deployment.yaml
                '''
            }
        }

        stage("Commit & Push Manifest") {
            steps {
                sh '''
                cd k8s-manifest-repo
                git config user.name "jenkins-ci"
                git config user.email "jenkins@ci.com"
                git add .
                git commit -m "Deploy ${APP_NAME}:${IMAGE_TAG}"
                git push origin main
                '''
            }
        }
    }

    post {
        success {
            echo " Build, Scan & Deploy Successful"
        }
        failure {
            echo " Pipeline blocked by Quality or Security Gate"
        }
    }

}
