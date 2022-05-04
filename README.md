                                                     **React application CI\CD Jenkins pipeline.**


Структура и порядок имплементации конвейера следующая:

* В рабочую директорию командой `git clone https://github.com/Victor-Iba-DevOps/nodejs-react-app` клонируется репозиторий с файлами исходного кода React-приложения и файлами, необходимыми для реализации конвейера. 
* На локальной машине устанавливается Docker, с его помощью (находясь в терминале в субдиректории `Jenkins_pipeline_files`) посредством команды `docker build -f Dockerfile_agent -t react-agent .` создается образ агента *"react-agent"* для сборки React-приложений. Для этого, согласно Докерфайлу [Dockerfile_agent](https://github.com/Victor-Iba-DevOps/nodejs-react-app/tree/main/Jenkins_pipeline_files/Dockerfile_agent), за основу берется дефолтный образ с репозитория Dockerhub для агентов Jenkins, подключаемых по протоколу SSH, -- [jenkins/ssh-agent:jdk11](https://hub.docker.com/layers/ssh-agent/jenkins/ssh-agent/jdk11/images/sha256-f9c02c0c92b515188e4b27da822f2845d743331e15f105271eb486c5232245f8), на котором уже добавлен user `Jenkins` с UID/GID=1000, Java runtime, SSH-agent, а далее с root правами на него добавляются необходимые утилиты и сертификаты, устанавливаются Docker Engine + cli, Node, npm, их успешная установка в образ проверяется при помощи команды `"--version"`, затем user Jenkins добавляется в группу пользователей, имеющих право управлять Docker, а GID самого докера внутри агента меняется на соответствующий GID Docker на локальной машине -- 980 (конкретный частный случай, для уточнения этого числа необходимо на локальной машине ввести команду `"getent group docker | cut -d ':' -f 3"` ). В результате этой операции получаем готовый образ агента `react-agent:latest`.
* Далее командой `docker-compose up -d` (флаг `-d` определяет то, что контейнеры будут запущены в фоновом режиме) запускаются два контейнера (Jenkins & Agent) согласно файлу [docker-compose.yml](https://github.com/Victor-Iba-DevOps/nodejs-react-app/blob/main/Jenkins_pipeline_files/docker-compose.yml), в котором прописано, что контейнер *"Jenkins"* будет запущен из дефолтного образа Jenkins с Dockerhub [jenkins/jenkins:lts-jdk11](https://hub.docker.com/layers/jenkins/jenkins/jenkins/lts-jdk11/images/sha256-ec98cb8b367b0f9426f71345efe11e001c901704cea0e61fd91beb37af34ef98?context=explore), на его порт 8080 с локальной машины будет проброшен аналогичный порт 8080, для связи по протоколу SSH с агентами открыт порт 22



// [docker-compose](https://git.zby.icdc.io/icdc/devops/labs/jenkins/-/blob/dev/Jenkins_pipeline_files/docker-compose.yml) подняты два контейнера  
// создание и копирование SSH ключей, добавление Credentials в Jenkins




// Идеи возможного улучшения конвейера:

//исключение node_modules для "npm install" при CleanupWS()

//добавление кода для сохранения логов ошибок при неудачных тестах через  Jest-JUnit