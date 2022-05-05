                                                React application CI\CD Jenkins pipeline.


Структура и порядок имплементации конвейера следующие:

*   В рабочую директорию командой `git clone https://github.com/Victor-Iba-DevOps/nodejs-react-app` клонируется репозиторий с файлами исходного кода React-приложения и файлами, необходимыми для реализации конвейера; 
   
*   На локальной машине устанавливается Docker, и с его помощью посредством команды `docker build -f Dockerfile_agent -t react-agent .` создается образ агента *react-agent* для сборки React-приложений. Для этого, согласно Докерфайлу [Dockerfile_agent](https://github.com/Victor-Iba-DevOps/nodejs-react-app/tree/main/Dockerfile_agent), за основу с репозитория Dockerhub берется дефолтный образ для агентов Jenkins, подключаемых по протоколу SSH, -- [jenkins/ssh-agent:jdk11](https://hub.docker.com/layers/ssh-agent/jenkins/ssh-agent/jdk11/images/sha256-f9c02c0c92b515188e4b27da822f2845d743331e15f105271eb486c5232245f8), на котором уже добавлен user *Jenkins* с UID/GID=1000, Java runtime, SSH-agent, а далее с root правами на него добавляются необходимые утилиты и сертификаты, устанавливаются Docker Engine + cli, Node, npm, их успешная установка в образ проверяется при помощи команды `--version`, затем user Jenkins добавляется в группу пользователей, имеющих право управлять Docker, а GID самого докера внутри агента меняется на соответствующий GID Docker на локальной машине -- 980 (конкретный частный случай, для уточнения этого числа необходимо на локальной машине ввести команду `getent group docker | cut -d ':' -f 3` ). В результате этой операции получаем готовый образ агента *react-agent:latest*;
   
*   Далее командой `docker-compose up -d` (флаг `-d` определяет то, что контейнеры будут запущены в фоновом режиме, не блокируя активный терминал) запускаются два контейнера *Jenkins* & *Agent* согласно файлу [docker-compose.yml](https://github.com/Victor-Iba-DevOps/nodejs-react-app/blob/main/docker-compose.yml), в котором прописано, что контейнер *"Jenkins"* будет запущен из дефолтного образа Jenkins с Dockerhub [jenkins/jenkins:lts-jdk11](https://hub.docker.com/layers/jenkins/jenkins/jenkins/lts-jdk11/images/sha256-ec98cb8b367b0f9426f71345efe11e001c901704cea0e61fd91beb37af34ef98?context=explore), ему будет присвоено имя "jenkins", на его порт 8080 будет проброшен соответствующий порт 8080 локальной машины, для сохранения данных (пароль администратора, плагины, настройки, построенные конвейеры и логи их работы и так далее) к директории `/var/jenkins_home/` контейнера создается и подключается статический *Docker volume*, названный "jenkins"; a контейнер *"Agent"* будет запускаться из созданного ранее образа `react-agent:latest`,ему присваивается имя "agent", он будет запускаться после старта контейнера "jenkins", он будет "слушать" внешние подключения по протоколу SSH по 22му порту, для сохранения необходимой информации (авторизованный ssh-ключ, файлы конфигураций и файл подключения Jenkins-контроллера) ему к директории `/home/jenkins/` будет создан и подключен статичный *Docker volume*, названный "react-node", а для управления Docker daemon локальной машины Docker'ом контейнера он будет подключен к нему через *Unix socket* (`/var/run/docker.sock:/var/run/docker.sock`). Оба контейнера будут автоматически перезапущены при рестарте машины или любых других условиях, кроме их остановки вручную командой `docker stop jenkins\agent`;
   
*   Для создания ssh ключа на агенте, который будет в этой паре выполнять фунцкию ssh-server, заходим в контейнер под пользователем jenkins командой `docker exec  -it --user jenkins agent bash`, проверяем, что мы находимся в home directory пользователя jenkins командой `pwd` (выводимый на экран результат должен быть `/home/jenkins`), здесь создаем скрытую папку .ssh и в ней создаем пару ssh-ключей командой `mkdir ~/.ssh && cd ~/.ssh/ && ssh-keygen -t rsa -f "jenkins_agent_key"`, добавляем публичный ключ в список авторизованных для подключения командой `cat jenkins_agent_key.pub >> ~/.ssh/authorized_keys`, устанавливаем необходимые уровни доступа к директории и ключам командой `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys ~/.ssh/jenkins_agent_key`. Выводим на экран содержимое приватного и публичного ключей командой `cat ~/.ssh/jenkins_agent_key` и `cat ~/.ssh/jenkins_agent_key.pub`, копируем их в отдельные временные файлы на локальной машине для настройки подключения Jenkins чуть позже и выходим из контейнера командой `exit`;

*   Далее в браузере локальной машины заходим по адресу [localhost:8080](localhost:8080) в графическую оболочку Jenkins, и так как это его первый запуск, Jenkins запросит автоматически сгенерированный пароль, сохраненный в его логах запуска (и продублированный в отдельном файле), воспользуемся командой `docker logs jenkins`, чтобы его найти и скопировать для разблокирования -- он будет между двух тройных рядов звёздочек в логе. Альтернативно, можем войти в контейнер командой `docker exec -it jenkins bash` и вывести пароль в терминал командой `cat /var/jenkins_home/secrets/initialAdminPassword`. Далее Jenkins предложит установить плагины по умолчанию и создать учетную запись администратора, после чего заходим в меню "*Manage jenkins > Configure system*" и в поле "*# of executors"* меняем значение на 0, для того, чтобы все задачи выполнялись не контроллером, а агентами. Проверяем установленные по умолчанию плагины и добавляем при необходимости следующие: *Credentials + Credentials Binding, Docker Pipeline, Docker, Pipeline: Basic Steps,  Pipeline: Declarative,  SSH Build Agents, SSH Credentials, Workspace Cleanup*;

*   Для подключения агента открываем меню `Manage Jenkins > Manage Nodes and Clouds > New Node`, называем наш агент к примеру "*React-builder*", выбираем для него опцию "*Permanent type*", затем в меню конфигурации ставим `1` в поле "*Number of executors*" (в правилах хорошего тона выставляется в зависимости от количества доступных процессорных ядер или потоков виртуальной машины, в этом случае есть только один линейный конвейер, поэтому можно оставить 1), в поле "*Remote root directory*" пишем адрес домашней директории пользователя jenkins (в ней у него будут права для создания, чтения и изменения файлов для копирования remoting.jar и управления через него агентом) `/home/jenkins`, в поле "*Labels*" -- `react` (для указания в декларативной части, что этот конвейер должен исполнять именно этот агент), в поле "*Usage*" -- что исполнять агент будет только те этапы и те конвейеры, в которых это непосредственно указано, в поле "*Launch method*" -- запуск посредством протокола ssh: в поле "*Host*" указываем имя контейнера `agent` (либо его адрес во внутренней сети, которую организовывает docker при запуске через docker-compose, его можно проверить, выполнив команду `docker inspect agent`, но он может варьироваться после перезапуска контейнера), в поле "*Credentials*" нажимаем "add", чтобы добавить ключ для подключения: *Global > SSH Username with private key > Global > ID (оставить поле пустым) >  Description = react agent ssh key > Username = jenkins > Private key = ставим галочку на "enter key directly" и вставляем в поле ключ, который взяли из `~/.ssh/jenkins_agent_key` в контейнере агента и сохранили в отдельном временном файле > сохраняем и добавляем ключ Credentials*, в поле "*Host Key Verification Strategy*" выбираем "Manually provided key verification strategy" и в поле "*SSH Key*" вставляем ключ, который скопировали из `~/.ssh/jenkins_agent_key.pub` контейнера агента, в поле "*Availability*" выбираем "*Bring this agent online when in demand and take him offline when idle*" (для удобства тестирования конвейера можно оставить агент всегда онлайн, но для практики экономии ресурсов агенты должны быть в спящем режиме, активироваться только по требованию контроллера для выполнения конкретных задач и обратно выключаться). Сохраняем выбранные настройки, нажимаем "*Launch agent*" и открываем лог подключения, он должен заканчиваться строкой *Agent successfully connected and online*.

*   Теперь можно приступать к созданию конвейера: *Jenkins dashboard > New Item*, выбираем имя для конвейера и "*Pipeline*", в настройках конвейера ставим галочки в полях "*GitHub project*" (и добавляем cюда [url github репозитория](https://github.com/Victor-Iba-DevOps/nodejs-react-app/), "*GitHub hook trigger for GITScm polling*" (для автоматической активации конвейера каждый раз, когда на репозитории обновляется или добавляется код в master ветке), 



// smee.io github webhook description


// Идеи возможного улучшения конвейера:

// исключение node_modules для "npm install" при CleanupWS()

//добавление кода для сохранения логов ошибок при неудачных тестах через  Jest-JUnit
