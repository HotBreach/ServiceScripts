#!/bin/bash
echo -n "Введите имя домена: "
read -r domain
echo -n "Введите имя сервера: "
# shellcheck disable=SC2034
read -r host
# shellcheck disable=SC2154
echo -n "Ваш домен $domain"
echo -n "Ваш сервер $host"
#Настройка сервера
sudo hostnamectl set-hostname $host
echo hostnamectl
echo "Выполнено!"
#Установка необходимых компонентов
sudo apt -y update
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
sudo bash -c "cat > /usr/share/pam-configs/mkhomedir" <<EOF

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
sudo realm permit 'Domain Admins'
sudo systemctl restart sssd
sudo cat > /etc/sudoers.d/domain_admins <<EOF
%Domain Admins@$domain     ALL=(ALL)   ALL
%DomainAdmins@$domain     ALL=(ALL)   ALL
%system\ super\ Domain Admins@$domain ALL=(ALL)       ALL
EOF
sudo chmod 0440 /etc/sudoers.d/domain_admins
sudo systemctl restart sssd
systemctl status sssd
echo "Выполнено!"
echo "Необходима перезегрузка"