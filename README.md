                                                React application CI\CD Jenkins pipeline.


Структура и порядок имплементации конвейера следующие:

*   В рабочую директорию командой `git clone https://github.com/Victor-Iba-DevOps/nodejs-react-app` клонируется репозиторий с файлами исходного кода React-приложения и файлами, необходимыми для реализации конвейера; 
*   На локальной машине устанавливается Docker, и с его помощью посредством команды `docker build -f Dockerfile_agent -t react-agent .` создается образ агента *"react-agent"* для сборки React-приложений. Для этого, согласно Докерфайлу [Dockerfile_agent](https://github.com/Victor-Iba-DevOps/nodejs-react-app/tree/main/Dockerfile_agent), за основу с репозитория Dockerhub берется дефолтный образ для агентов Jenkins, подключаемых по протоколу SSH, -- [jenkins/ssh-agent:jdk11](https://hub.docker.com/layers/ssh-agent/jenkins/ssh-agent/jdk11/images/sha256-f9c02c0c92b515188e4b27da822f2845d743331e15f105271eb486c5232245f8), на котором уже добавлен user `Jenkins` с UID/GID=1000, Java runtime, SSH-agent, а далее с root правами на него добавляются необходимые утилиты и сертификаты, устанавливаются Docker Engine + cli, Node, npm, их успешная установка в образ проверяется при помощи команды `--version`, затем user Jenkins добавляется в группу пользователей, имеющих право управлять Docker, а GID самого докера внутри агента меняется на соответствующий GID Docker на локальной машине -- 980 (конкретный частный случай, для уточнения этого числа необходимо на локальной машине ввести команду `getent group docker | cut -d ':' -f 3` ). В результате этой операции получаем готовый образ агента `react-agent:latest`;
*   Далее командой `docker-compose up -d` (флаг `-d` определяет то, что контейнеры будут запущены в фоновом режиме, не блокируя активный терминал) запускаются два контейнера Jenkins & Agent согласно файлу [docker-compose.yml](https://github.com/Victor-Iba-DevOps/nodejs-react-app/blob/main/docker-compose.yml), в котором прописано, что контейнер "Jenkins" будет запущен из дефолтного образа Jenkins с Dockerhub [jenkins/jenkins:lts-jdk11](https://hub.docker.com/layers/jenkins/jenkins/jenkins/lts-jdk11/images/sha256-ec98cb8b367b0f9426f71345efe11e001c901704cea0e61fd91beb37af34ef98?context=explore), ему будет присвоено имя "jenkins", на его порт 8080 будет проброшен соответствующий порт 8080 локальной машины, для сохранения данных (пароль администратора, плагины, настройки, построенные конвейеры и логи их работы и так далее) к директории `/var/jenkins_home/` контейнера создается и подключается статический Docker volume, названный "jenkins"; a контейнер "Agent" будет запускаться из созданного ранее образа `react-agent:latest`,ему присваивается имя "agent", он будет запускаться после старта контейнера "jenkins", он будет "слушать" внешние подключения по протоколу SSH по 22му порту, для сохранения необходимой информации (авторизованный ssh-ключ, файлы конфигураций и файл подключения Jenkins-контроллера) ему к директории `/home/jenkins/` будет создан и подключен статичный Docker volume, названный "react-node", а для управления Docker daemon локальной машины Docker'ом контейнера он будет подключен к нему через Unix socket (`/var/run/docker.sock:/var/run/docker.sock`). Оба контейнера будут автоматически перезапущены при рестарте машины или любых других условиях, кроме их остановки вручную командой `docker stop jenkins\agent`.
*   Для создания ssh ключа на агенте, который будет в этой паре выполнять фунцкию ssh-server, заходим в контейнер под пользователем jenkins командой `docker exec  -it --user jenkins agent bash`, проверяем, что мы находимся в home directory пользователя jenkins командой `pwd` (выводимый на экран результат должен быть `/home/jenkins`), здесь создаем скрытую папку .ssh и в ней создаем пару ssh-ключей командой `mkdir ~/.ssh && cd ~/.ssh/ && ssh-keygen -t rsa -f "jenkins_agent_key"`, добавляем публичный ключ в список авторизованных для подключения командой `cat jenkins_agent_key.pub >> ~/.ssh/authorized_keys`, устанавливаем необходимые уровни доступа к директории и ключам командой `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys ~/.ssh/jenkins_agent_key`, выводим на экран содержимое приватного ключа командой `cat ~/.ssh/jenkins_agent_key` и копируем его в буфер обмена на локальной машине. Далее заходим по адресу [localhost:8080](localhost:8080) в 



// разблокирование кодом и установка лог\пароль Jenkins 
// создание и копирование SSH ключей, добавление Credentials в Jenkins
// настройка Jenkins, плагины, подключение ноды агента, экзекуторы 0:1


// Идеи возможного улучшения конвейера:
// исключение node_modules для "npm install" при CleanupWS()
//добавление кода для сохранения логов ошибок при неудачных тестах через  Jest-JUnit