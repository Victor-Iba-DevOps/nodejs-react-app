                                                     **React application CI\CD Jenkins pipeline.**


Структура и порядок имплементации конвейера следующая:

* В рабочую директорию командой `git clone https://github.com/Victor-Iba-DevOps/nodejs-react-app` клонируется репозиторий с файлами исходного кода React-приложения и файлами, необходимыми для реализации конвейера. 
* На локальной машине устанавливается Docker, с его помощью (находясь в терминале в рабочей директории) посредством команды `"docker build -f Dockerfile_agent -t react-agent ."` создается образ агента "react-agent" для сборки React-приложений. Для этого, согласно Докерфайлу [Dockerfile_agent](https://github.com/Victor-Iba-DevOps/nodejs-react-app/tree/main/Jenkins_pipeline_files/Dockerfile_agent), за основу берется дефолтный образ для агентов Jenkins, подключаемых по протоколу SSH, -- ([jenkins/ssh-agent:jdk11](https://hub.docker.com/r/jenkins/ssh-agent)), на котором уже добавлен user Jenkins с UID/GID=1000, Java runtime, SSH-agent, далее с root правами на него добавляются необходимые утилиты и сертификаты, устанавливаются Docker Engine + cli, Node, npm, и проверяются при помощи `"--version"`, затем user Jenkins добавляется в группу пользователей, имеющих право управлять Docker, а GID самого докера меняется на 980 (конкретный частный случай, для уточнения этого числа необходимо на локальной машине ввести команду `"getent group docker | cut -d ':' -f 3"` ). В результате этой операции получаем готовый образ агента `react-agent:latest`.
* 



// [docker-compose](https://git.zby.icdc.io/icdc/devops/labs/jenkins/-/blob/dev/Jenkins_pipeline_files/docker-compose.yml) подняты два контейнера  
// создание и копирование SSH ключей, добавление Credentials в Jenkins




// Идеи возможного улучшения конвейера:

//исключение node_modules для "npm install" при CleanupWS()

//добавление кода для сохранения логов ошибок при неудачных тестах через  Jest-JUnit