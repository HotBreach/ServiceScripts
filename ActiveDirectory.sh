#!/bin/bash
echo -n "Введите имя домена: "
read -r domain
echo -n "Введите имя сервера: "
# shellcheck disable=SC2034
read -r host
# shellcheck disable=SC2154
#Настройка сервера
sudo hostnamectl set-hostname "$host"
hostname
echo "Выполнено!"
#Настройка модуля adutil
echo "Начинаем настройку adutil"
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt -y update
sudo apt-get remove adutil-preview
sudo ACCEPT_EULA=Y apt-get install -y adutil
#Установка необходимых компонентов
sudo apt -y install realmd libnss-sss libpam-sss sssd sssd-tools adcli samba-common-bin oddjob oddjob-mkhomedir packagekit
echo "Выполнено!"
#Поиск контроллера домена 
sudo realm discover $domain
#Подключение к Active Directory
echo "Введите логин администратора: "
# shellcheck disable=SC2034
read -r login
sudo realm join -U $login $domain 
realm list 
echo "Выполнено!"
#Настройка служебных параментров интеграции 
sudo cat > /usr/share/pam-configs/mkhomedir <<EOF

Name: activate mkhomedir

Default: yes

Priority: 900

Session-Type: Additional

Session:

required                        pam_mkhomedir.so umask=0022 skel=/etc/skel

EOF
sudo pam-auth-update
sudo systemctl restart sssd 
#Настройка доступа к серверу 
sudo realm permit -g 'Domain Admins'@$domain
sudo realm permit $login
sudo systemctl restart sssd
sudo cat > /etc/sudoers.d/domain_admins <<EOF
%domain\ admins        ALL=(ALL)     ALL
EOF
sudo chmod 0440 /etc/sudoers.d/domain_admins
sudo systemctl restart sssd
#Настройка файла /etc/sssd/sssd.conf и отключение имени домена на сервере
sudo sed -i '16 s/True/False/' /etc/sssd/sssd.conf
sudo systemctl restart sssd
systemctl status sssd
echo "Выполнено!"
sudo systemctl enable sssd
sudo systemctl start sssd
sudo systemctl status sssd
echo "Выполнен рестарт служб"