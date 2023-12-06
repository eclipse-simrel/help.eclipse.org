pipeline {
  agent any
  options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 15, unit: 'MINUTES')
    disableConcurrentBuilds()
  }
  tools {
    jdk 'oracle-jdk8-latest'
  }
  parameters {
    string(name: 'release_name', defaultValue: '', description: 'e.g. 2020-06')
    booleanParam(name: 'use_latest_platform', defaultValue: true, description: '')
    string(name: 'path_to_platform_archive', defaultValue: '', description: 'Only relevant if $use_latest_platform is disabled! <br/> Path to eclipse platform archive that is used for the info center (base path: /home/data/httpd/download.eclipse.org/eclipse/downloads/drops4) e.g. R-4.16-202006040540/')
    choice(name: 'p2_repo_dir', choices: ["releases/2023-12/202312061001", "releases/2023-09/202309131000", "releases/2023-06/202306141000"] , description: 'Path to P2 repository that is used for the info center (base path: /home/data/httpd/download.eclipse.org)<br/> Dir can be found here: <a href="https://download.eclipse.org/releases/">https://download.eclipse.org/releases/</a> &lt;release&gt;')
    booleanParam(name: 'past_release', defaultValue: false, description: 'Change banner to say "Past release" instead of "Current release". Enable this for all releases but the latest!')
  }
  environment {
    SSH_REMOTE = "genie.simrel@projects-storage.eclipse.org"
  }
  stages {
    stage('Create docker image') {
      steps {
        sshagent(['projects-storage.eclipse.org-bot-ssh']) {
          sh '''
            set +x
            echo "use_latest_platform: ${use_latest_platform}"
            if ${use_latest_platform}; then
              base_dir="/home/data/httpd/download.eclipse.org/eclipse/downloads/drops4"
              ssh "${SSH_REMOTE}" ls -a1d ${base_dir}/R-*
              latest_r_build_dir=$(ssh "${SSH_REMOTE}" ls -1d ${base_dir}/R-* | tail -n 1)
              path_to_platform_archive=$(ssh "${SSH_REMOTE}" ls -1 ${latest_r_build_dir}/eclipse-platform-*linux-gtk-x86_64.tar.gz)
              #cut of base dir
              path_to_platform_archive=${path_to_platform_archive#${base_dir}/}
            fi
            platform_archive_subdir=${path_to_platform_archive%/eclipse-*}
            echo "platform_archive_subdir:"
            echo ${platform_archive_subdir}

            cd app
            chmod +x *.sh
            ./createInfoCenter.sh ${release_name} ${platform_archive_subdir} ${p2_repo_dir} ${past_release}

            ls -al ${release_name}/eclipse/dropins/plugins >> doc_plugin_list.txt
          '''
        }
        stash includes: 'app/info-center*.tar.gz', name: 'infocenter_archive'
        archiveArtifacts artifacts: '**/doc_plugin_list.txt', followSymlinks: false
        cleanWs()
      }
    }
    stage('Build and push docker image') {
      agent {
        label 'docker-build'
      }
      steps {
        unstash 'infocenter_archive'
        withDockerRegistry([credentialsId: 'dockerhub-bot', url: 'https://index.docker.io/v1/']) {
            sh '''
              rm -rf docker/info-center*.tar.gz
              mv app/info-center*.tar.gz docker/
              cd docker/
              ./build_infocenter_docker_img.sh ${release_name}
            '''
        }
      }
    }
  }
  post {
    failure {
      mail to: 'frederic.gurr@eclipse-foundation.org',
        subject: "Build Failure ${currentBuild.fullDisplayName}",
        mimeType: 'text/html',
        body: "Project: ${env.JOB_NAME}<br/>Build Number: ${env.BUILD_NUMBER}<br/>Build URL: ${env.BUILD_URL}<br/>Console: ${env.BUILD_URL}/console"
    }
    fixed {
      mail to: 'frederic.gurr@eclipse-foundation.org',
        subject: "Back to normal ${currentBuild.fullDisplayName}",
        mimeType: 'text/html',
        body: "Project: ${env.JOB_NAME}<br/>Build Number: ${env.BUILD_NUMBER}<br/>Build URL: ${env.BUILD_URL}<br/>Console: ${env.BUILD_URL}/console"
    }
  }
}
