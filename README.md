                                                React application CI\CD Jenkins pipeline.


Структура и порядок имплементации конвейера следующие:

*   В рабочую директорию локальной машины командой `git clone https://github.com/Victor-Iba-DevOps/nodejs-react-app` клонируется репозиторий с файлами исходного кода React-приложения и файлами, необходимыми для реализации конвейера. Делаем файлы скриптов *codechange.sh* и *codechangeback.sh* исполняемыми командой `sudo chmod u+x codechange.sh codechangeback.sh`; 
   
*   На локальной машине устанавливается Docker, и с его помощью посредством команды `docker build -f Dockerfile_agent -t react-agent .` создается образ агента *react-agent* для сборки React-приложений. Для этого, согласно Докерфайлу [Dockerfile_agent](https://github.com/Victor-Iba-DevOps/nodejs-react-app/tree/main/Dockerfile_agent), за основу с репозитория Dockerhub берется дефолтный образ для агентов Jenkins, подключаемых по протоколу SSH, -- [jenkins/ssh-agent:jdk11](https://hub.docker.com/layers/ssh-agent/jenkins/ssh-agent/jdk11/images/sha256-f9c02c0c92b515188e4b27da822f2845d743331e15f105271eb486c5232245f8), на котором уже добавлен user *Jenkins* с UID/GID=1000, Java runtime, SSH-agent, а далее с root правами на него добавляются необходимые утилиты и сертификаты, устанавливаются Docker Engine + cli, Node, npm, их успешная установка в образ проверяется при помощи команды `--version`, затем user Jenkins добавляется в группу пользователей, имеющих право управлять Docker, а GID самого докера внутри агента меняется на соответствующий GID Docker на локальной машине -- 980 (конкретный частный случай, для уточнения этого числа необходимо на локальной машине ввести команду `getent group docker | cut -d ':' -f 3` ). В результате этой операции получаем готовый образ агента *react-agent:latest*;
   
*   Далее командой `docker-compose up -d` (флаг `-d` определяет то, что контейнеры будут запущены в фоновом режиме, не блокируя активный терминал) запускаются два контейнера *Jenkins* & *Agent* согласно файлу [docker-compose.yml](https://github.com/Victor-Iba-DevOps/nodejs-react-app/blob/main/docker-compose.yml), в котором прописано, что контейнер *"Jenkins"* будет запущен из дефолтного образа Jenkins с Dockerhub [jenkins/jenkins:lts-jdk11](https://hub.docker.com/layers/jenkins/jenkins/jenkins/lts-jdk11/images/sha256-ec98cb8b367b0f9426f71345efe11e001c901704cea0e61fd91beb37af34ef98?context=explore), ему будет присвоено имя "jenkins", на его порт 8080 будет проброшен соответствующий порт 8080 локальной машины, для сохранения данных (пароль администратора, плагины, настройки, построенные конвейеры и логи их работы и так далее) к директории `/var/jenkins_home/` контейнера создается и подключается статический *Docker volume*, названный "jenkins"; a контейнер *"Agent"* будет запускаться из созданного ранее образа `react-agent:latest`,ему присваивается имя "agent", он будет запускаться после старта контейнера "jenkins", он будет "слушать" внешние подключения по протоколу SSH по 22му порту, для сохранения необходимой информации (авторизованный ssh-ключ, файлы конфигураций и файл подключения Jenkins-контроллера) ему к директории `/home/jenkins/` будет создан и подключен статичный *Docker volume*, названный "react-node", а для управления Docker daemon локальной машины Docker'ом контейнера он будет подключен к нему через *Unix socket* (`/var/run/docker.sock:/var/run/docker.sock`) (Такая "подмена" необходима из-за того, что попытки создавать новые образы в контейнеризованном приложении с установленным внутри этого контейнера Docker могут создавать [конфликты и угрозы безопасности](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/), а методом подключения через Docker socket мы симулируем агент с установленным на нём Docker, где ход выполнения конвейера будет аналогичным удалённому серверу или виртуальной машине). Оба контейнера будут автоматически перезапущены при рестарте машины или любых других условиях, кроме их остановки вручную командой `docker stop jenkins\agent`;
   
*   Для создания ssh ключа на агенте, который будет в этой паре выполнять фунцкию ssh-server, заходим в контейнер под пользователем jenkins командой `docker exec  -it --user jenkins agent bash`, проверяем, что мы находимся в home directory пользователя jenkins командой `pwd` (выводимый на экран результат должен быть `/home/jenkins`), здесь создаем скрытую папку .ssh и в ней создаем пару ssh-ключей командой `mkdir ~/.ssh && cd ~/.ssh/ && ssh-keygen -t rsa -f "jenkins_agent_key"`, добавляем публичный ключ в список авторизованных для подключения командой `cat jenkins_agent_key.pub >> ~/.ssh/authorized_keys`, устанавливаем необходимые уровни доступа к директории и ключам командой `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys ~/.ssh/jenkins_agent_key`. Выводим на экран содержимое приватного и публичного ключей командой `cat ~/.ssh/jenkins_agent_key` и `cat ~/.ssh/jenkins_agent_key.pub`, копируем их в отдельные временные файлы на локальной машине для настройки подключения Jenkins чуть позже и выходим из контейнера командой `exit`;

*   Далее в браузере локальной машины заходим по адресу [localhost:8080](localhost:8080) в графическую оболочку Jenkins, и так как это его первый запуск, Jenkins запросит автоматически сгенерированный пароль, сохраненный в его логах запуска (и продублированный в отдельном файле), воспользуемся командой `docker logs jenkins`, чтобы его найти и скопировать для разблокирования -- он будет между двух тройных рядов звёздочек в логе. Альтернативно, можем войти в контейнер командой `docker exec -it jenkins bash` и вывести пароль в терминал командой `cat /var/jenkins_home/secrets/initialAdminPassword`. Далее Jenkins предложит установить плагины по умолчанию и создать учетную запись администратора, после чего заходим в меню "*Manage jenkins > Configure system*" и в поле "*# of executors"* меняем значение на 0, для того, чтобы все задачи выполнялись не контроллером, а агентами. Проверяем установленные по умолчанию плагины и добавляем при необходимости следующие: *Credentials + Credentials Binding, Docker Pipeline, Docker, Pipeline: Basic Steps,  Pipeline: Declarative,  SSH Build Agents, SSH Credentials, Workspace Cleanup*;

*   Для подключения агента открываем меню *Manage Jenkins > Manage Nodes and Clouds > New Node*, называем наш агент к примеру "*React-builder*", выбираем для него опцию "*Permanent type*", затем в меню конфигурации ставим `1` в поле "*Number of executors*" (в правилах хорошего тона выставляется в зависимости от количества доступных процессорных ядер или потоков виртуальной машины, в этом случае есть только один линейный конвейер, поэтому можно оставить 1), в поле "*Remote root directory*" пишем адрес домашней директории пользователя jenkins `/home/jenkins` (в ней у него будут права для создания, чтения и изменения файлов для копирования remoting.jar и управления через него агентом), в поле "*Labels*" -- `react` (для указания в декларативной части, что этот конвейер должен исполнять именно этот агент), в поле "*Usage*" -- что исполнять агент будет только те этапы и те конвейеры, в которых это непосредственно указано, в поле "*Launch method*" -- запуск посредством протокола ssh: в поле "*Host*" указываем имя контейнера `agent` (либо его адрес во внутренней сети, которую организовывает docker при запуске через docker-compose, его можно проверить, выполнив команду `docker inspect agent`, но он может варьироваться после перезапуска контейнера), в поле "*Credentials*" нажимаем "add", чтобы добавить ключ для подключения: *Global > SSH Username with private key > Global > ID (оставить поле пустым) >  Description = react agent ssh key > Username = jenkins > Private key = ставим галочку на "enter key directly" и вставляем в поле ключ, который взяли из `~/.ssh/jenkins_agent_key` в контейнере агента и сохранили в отдельном временном файле > сохраняем и добавляем ключ Credentials*, в поле "*Host Key Verification Strategy*" выбираем "Manually provided key verification strategy" и в поле "*SSH Key*" вставляем ключ, который скопировали из `~/.ssh/jenkins_agent_key.pub` контейнера агента, в поле "*Availability*" выбираем "*Bring this agent online when in demand and take him offline when idle*" (для удобства тестирования конвейера можно оставить агент всегда онлайн, но для практики экономии ресурсов агенты должны быть в спящем режиме, активироваться только по требованию контроллера для выполнения конкретных задач и обратно выключаться). Сохраняем выбранные настройки, нажимаем "*Launch agent*" и открываем лог подключения, он должен заканчиваться строкой *Agent successfully connected and online*;

*   Теперь можно приступать к созданию конвейера: *Jenkins dashboard > New Item > Multibranch Pipeline*, выбираем имя для конвейера, в настройках конвейера ставим галочки в полях "GitHub project" (и добавляем cюда [url github репозитория](https://github.com/Victor-Iba-DevOps/nodejs-react-app/)), *GitHub hook trigger for GITScm polling* (для автоматической активации конвейера каждый раз, когда на репозитории обновляется или добавляется код), в *Definition* выбираем из выпадающего меню "*Pipeline script from SCM*", в *SCM* -- "*Git*", в *Repository url* добавляем [url github репозитория](https://github.com/Victor-Iba-DevOps/nodejs-react-app/), в *Branch specifier" указываем ветку (по умолчанию это *master*, в данном случае у меня главная ветка названа *main*), а в поле *Script path* указываем `Jenkinsfile` без уточнений, поскольку он лежит в корневой директории репозитория. Сохраняем настройки конвейера и возвращаемся на *dashboard*;

*   Так как локальная машина находится за фаерволом, можно открыть в нем 8080 порт, чтобы к Jenkins поступали сигналы от Github об обновлении кода на репозитории. Для того, чтобы не компрометировать этим локальную сеть (либо в условиях отсутствия доступа к администрированию фаервола) можно воспользоваться webhook proxy утилитой [smee.io](https://smee.io/), которая устанавливается на локальную машину командой `npm install -g smee-client`, затем в браузере открывается [новый канал](https://smee.io/new), где сайт автоматически присвоит и выдаст *url*, который подвязывается к установленной утилите терминале командой `smee -u https://#url# --path /github-webhook/ --port 8080`, что позволит получать Jenkins на своем порту 8080 сигналы. Его же нужно добавить и в настройки Github репозитория, чтобы он отправлял push events: *Settings > Webhooks > Add Webhook*, вставляем *url* в поле "Payload url", в поле "*content type*" указываем "application/json", выбираем "Just the push event" в меню "*Which events would you like to trigger this webhook*" и сохраняем эти настройки;

*   Для того, чтобы собранные конвейером образы приложения могли быть залиты на удаленный репозиторий в ходе выполнения конвейера, нужно внести реквизиты учетной записи в Jenkins. В моем случае я воспользовался открытым репозиторием [Dockerhub](https://hub.docker.com/repository/docker/victoribatraineedevops/training-repo). Заходим в меню *Manage Jenkins > Security > Manage Credentials*, в таблице "*Stores scoped to Jenkins*" нажимаем на "*global*", на новой странице нажимаем "*Add Credentials*": *Kind = Username with password, Scope = Global, Username = Dockerhub_username, Password = Dockerhub_password, ID = DockerhubID (можно назвать как удобно)*, сохраняем реквизиты;

*   Пройдемся по порядку по заданным в Jenkinsfile командам: 

1.  В Environment объявлена переменная *credentials*, которая берет данные при обращении к ней из *'DockerhubID' credentials*, и переменная *Image*.
2.  В options установлен параметр *skipStagesAfterUnstable*, который остановит выполнение конвейера, если на какой-либо из его стадий произойдет ошибка исполнения или неожиданное событие.
3.  Исполняющим агентом назначены агенты с меткой*'react'*, и так как такой у нас один, то выполнять поставленные задачи будет выполнять именно он, а не контроллер или какие-либо другие агенты.
4.  На стадии *Install* команда `npm install` устанавливает в рабочую директорию *~/workspace/nodejs-react-app/node_modules/* React приложение из директории *./src* и все необходимые зависимости для построения данного приложения, перечисленные в файле *package.json*.
5.  На стадии *Test* командой `npm test` вызывается фреймворк для тестирования приложений *Jest*, который проверяет, корректно ли отрисовывается установленное React приложение.
6.  На стадии *Build* командой `npm run build` из файлов установленного приложения создается оптимизированный для развертывания на веб-сервере билд приложения и он помещается в директорию *./build*.
7.  На стадии *Push* сперва запускается скрипт (так как декларативный метод построения конвейера не позволяет напрямую задавать подобные команды, то они используюся в блоке *script{}*), в котором переменная *Image* принимает на себя результат команды `docker.build("victoribatraineedevops/training-repo:1.${env.BUILD_ID}")`, в которой указывается, что *tag* собираемого образа будет соответствовать репозиторию, на который он будет впоследствии загружаться, с текущим порядковым номером билда *Jenkins*, сборка образа будет проходит согласно *Dockerfile* (так как в команде отдельно не указан другой *dockerfile*), находящемуся в корне репозитория GitHub. В *Dockerfile* указано, что за основу берется образ [nginx:stable-alpine](https://hub.docker.com/layers/nginx/library/nginx/stable-alpine/images/sha256-72defb0353f4fb7a3869a2b89d92fbc3b6a99b48d1b960bba092fa3c8d093eed) c *Dockerhub* (минимального размера веб-сервер для развертывания приложения) и в его директорию */usr/share/nginx/html* копируются файлы билда React приложения из директории *build/* нашего агента. Затем командой `docker.withRegistry('', credentials)` запускается процесс логина в *Dockerhub* (так как не указан адрес какого-то другого репозитория, *Dockerhub* используется по умолчанию) под именем и паролем, указанным в *DockerhubID credentials*,  и после авторизации командой `Image.push()` содержимое переменной *Image* -- а это построенный Docker образ веб-сервера nginx с React приложением -- загружается в удаленный репозиторий. Далее командой `sh 'docker logout'` производится разлогинивание из *Dockerhub* и удаление реквизитов из временного файла в агенте, и командой `sh "docker rmi nginx:stable-alpine victoribatraineedevops/training-repo:1.${env.BUILD_ID}"` удаляются из реестра и устройств хранения на агенте (в данном случае *docker daemon* агента подключен к докеру на локалхосте, который выполняет все эти и следующие команды и хранит образы, но в общем принципе агентом должен служить удаленный сервер или виртуальная машина) скачанный в этой стадии образ nginx и созданный образ веб-сервера с установленным приложением.
8.  На стадии *Deploy* перед развертыванием нового приложения необходимо убедиться, что старые версии приложения и образы, с которых они запускаются, остановлены и удалены. Для этого используются два идентичных script блока *try{} catch(err){}*, которые сперва пытаются остановить и удалить контейнер и образ, и если команда проходит успешно, то выводит на экран сообщение об удалении старых версий и продолжении выполнения конвейера, а при получении ошибки от docker при выполнении команды (если к примеру это первый запуск, то на агенте не может быть образа и контейнера развернутого приложения, или же по какой-то причине будет отсутствовать один из них или оба) на экран выводится сообщение о том, что предыдущей версии приложения не найдено и продолжении выполнения конвейера, статус выполнения стадии остаётся успешным несмотря на возможные полученные ошибки, так как все возможные варианты результата выполнения команд нас будут устраивать, и конвейер продолжает развертывание приложения. Далее командой `sh "docker run -d --restart unless-stopped --name reactapp -p 4000:80 victoribatraineedevops/training-repo:1.${env.BUILD_ID}"` запускается в режиме *detached* контейнер с заданным именем *reactapp* с пробросом на его 80й порт c 4000го порта локальной машины (чтобы мы могли для данного примера зайти на [localhost:4000](localhost:4000) и проверить, как выглядит приложение) с политикой автоматического перезапуска при любых условиях (это может быть к примеру рестарт виртуальной машины или временное аварийное отключение питания сервера), что позволит повысить uptime развернутого приложения без необходимости ручного воздействия в критических ситуациях.
9.  Последней стадией *post* после окончания работы конвейера, будь это успешное развертывание приложения или аварийная остановка из-за ошибки на какой-либо из его стадий, проходит удаление командой `cleanWs()` всей информации , хранящейся в рабочей директории *~/workspace* агента, в частности файлы исходных кодов, которые безусловно должны загружаться заново при каждом изменении на репозитории, чтобы не допускать конфликтов версий и гарантированно каждый раз строить новые приложения из нового кода.

*  Подготовительные шаги завершены, можем запускать наш конвейер, на первый раз вручную, чтобы протестировать все элементы, просмотреть лог вывода консоли и сравнить его с ожидаемыми результатами. Выбираем на *dashboard* конвейер, в меню слева нажимаем "*Build Now*", снизу в меню "*Build History*" появится новая строка "*#{build_number}*"(в этом случае это будет #1), нажимаем на нее, и в новом окне слева выбираем "*Console Output*", который в режиме реального времени будет отображать текущие операции конвейера и их результат. Если все необходимые условия были соблюдены, то все стадии должны пройти успешно, в конце *Console Output Log* будет строка *Finished: SUCCESS* и по адресу [localhost:4000](localhost:4000) нас приветствует развернутое React приложение.

*  Для демонстрации автоматической работы всей цепочки по сборке приложения по триггеру webhook при каждом обновлении кода на *Github* репозитории в терминале находясь в рабочей директории запускаем скрипт командой `./codechange.sh`, который заменяет исходный код приложения на слегка измененную версию из папки "*srcnew*" и отправляет новый коммит на *Github* , тем самым запуская всю цепочку выполнения конвейера снова, уже с новым кодом, после чего нужно обновить страницу в браузере, чтобы увидеть новую версию React приложения. В репозитории для удобства добавлен скрипт `./codechangeback.sh`, который возвращает код в исходное состояние и опять же push'ит его на Github, запуская опять Jenkins конвейер и развертывание старой версии приложения. 


                                                    Идеи возможного улучшения работы конвейера:


*  В стадии *post* можно было бы настроить исключение директории *node_modules*, где лежат необходимые для постройки билда приложения зависимости от удаления, чтобы они не скачивались каждый раз при запуске конвейера, сэкономив тем самым около 5-10 секунд, но тогда при очистке workspace агента могут оставаться ненужные или устаревшие файлы зависимостей, потенциально создавая конфликты и угрозу безопасности.

*  В стадии *Test* можно было бы при необходимости добавить более тщательные тесты для проверки других параметров приложения, нежели просто корректная отрисовка страницы, и добавлить плагин Jest-JUnit (или другие для специализированных тестов) в Jenkins для сохранения логов ошибок при неудачных результатах тестов для передачи специалистам тестирования для детального изучения.

 *  В стадии *Push* Jenkins при выполении скрипта `docker.withRegistry('', credentials)` вводит из реквизиты для логина на Dockerhub через cli, и они около десяти секунд хранятся в агенте в файле *config.json* во временной директории с рандомным названием, пока конвейер не дойдет до команды `docker logout`, когда этот файл удаляется. Возможно, есть путь минимализация окна времени хранения реквизитов в таком незащищенном виде или замены этой операции на более безопасную.

*   В стадии *Deploy* время между остановкой контейнера командой `sh 'docker stop reactapp && docker rm reactapp'` и развертыванием новой версии командой `sh "docker run -d --restart unless-stopped --name reactapp -p 4000:80 victoribatraineedevops/training-repo:1.${env.BUILD_ID}"` -- это около 15 секунд downtime, когда ни старая ни новая версия приложения недоступны. Возможно, есть путь сокращения этого времени для минимизации downtime.
