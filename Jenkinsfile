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
                  Image.push 'latest'
               }
            }
            sh 'docker logout'
            sh "docker rmi nginx:stable-alpine victoribatraineedevops/training-repo:1.${env.BUILD_ID} victoribatraineedevops/training-repo:latest"
         }
      }
      stage('Deploy') {
         agent {
            kubernetes {
               inheritFrom 'kubernetes'
            }
         }
         steps {
            script {
               sh 'sed -i "s/latest/1.${BUILD_NUMBER}/" reactapp.yml'
               kubernetesDeploy(configs: "reactapp.yml", kubeconfigId: "kubernetesConfig")
            }
         }
      }
   }   
   post {
      success {
         updateGitlabCommitStatus name: 'build', state: 'success'
      }
      always {
         cleanWs()
      }
   }
}