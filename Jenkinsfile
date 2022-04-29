pipeline {
 agent { label 'react' }
 environment { Image = ''
               credentials = 'DockerhubID' }   
 options {   skipDefaultCheckout(true)
             skipStagesAfterUnstable() }
    stages {
      stage('Install') {
         steps {  checkout scm
                  sh 'npm install' }
      }
      stage('Test') {
         steps {  sh 'npm test' }
      }
      stage('Build') {                           
         steps {  sh 'npm run build'  }                                      
      }                                          
      stage('Push') { 
         steps { 
            script {   docker.withRegistry('', credentials ) {
                       Image=docker.build("victoribatraineedevops/training-repo:1.${env.BUILD_ID}")
                       Image.push()    }
            }
                  sh "docker rmi victoribatraineedevops/training-repo:1.${env.BUILD_ID}"
         }
      }
      stage('Deploy') {
         steps {
           script {
             try { sh "docker stop reactapp"
                   echo "Previously deployed application is removed, proceeding with the deployment of new version." }
             catch (err) { echo "No previously deployed applications were detected, proceeding with the deployment of new version."
                          currentBuild.result = 'SUCCESS' } 
           }
           script {
             try { sh "docker rmi -f \$(docker images -a -q 'victoribatraineedevops/training-repo')"
                   echo "Previously deployed application versions are removed, proceeding with the deployment of new version." }
             catch (err) { echo "No previously deployed application versions were detected, proceeding with the deployment of new version."
                          currentBuild.result = 'SUCCESS' } 
           }
                  sh "docker run -d --rm --name reactapp -p 4000:80 victoribatraineedevops/training-repo:1.${env.BUILD_ID}"
                  cleanWs()
         }
      }
  }
}
