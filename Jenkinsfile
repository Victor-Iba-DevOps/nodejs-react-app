pipeline {
   environment { 
      Image = ''
      credentials='DockerhubID'
   }   
   options {
      skipStagesAfterUnstable() 
   }
   agent {
      label 'react' 
   }
   stages {
      stage('Install') {
         steps {
            sh 'npm install'
         }
      }
      stage('Test') {
         steps {
            sh 'npm test'
         }
      }
      stage('Build') {
         steps {
            sh 'npm run build'
         } 
      }
      stage('Push') {
         steps {
            script {
               Image=docker.build("victoribatraineedevops/training-repo:1.${env.BUILD_ID}")
               docker.withRegistry('', credentials ) {
                  Image.push()
               }
            }
            sh 'docker logout'
            sh "docker rmi nginx:stable-alpine victoribatraineedevops/training-repo:1.${env.BUILD_ID}"
         }
      }
      stage('Deploy') {
         steps {
            script {
               try {
                  sh 'docker stop reactapp && docker rm reactapp'
                  echo 'Previously deployed application is removed, proceeding with the deployment of new version.'
               }
               catch (err) {
                  echo 'No previously deployed applications were detected, proceeding with the deployment of new version.'
                  currentBuild.result = 'SUCCESS'
               }
            }
            script {
               try {
                  sh "docker rmi -f \$(docker images -a -q 'victoribatraineedevops/training-repo')"
                  echo 'Previously deployed application versions are removed, proceeding with the deployment of new version.'
               }
               catch (err) {
                  echo 'No previously deployed application versions were detected, proceeding with the deployment of new version.'
                  currentBuild.result = 'SUCCESS'
               }
            }
            sh "docker run -d --restart unless-stopped --name reactapp -p 4000:80 victoribatraineedevops/training-repo:1.${env.BUILD_ID}"
         }
      }
   }
   post {
      always {
         cleanWs()
      }
   }
}
