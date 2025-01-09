#!/bin/bash

# Функция для проверки прав root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "\033[31mПожалуйста, запустите скрипт с правами root.\033[0m"
    exit 1
  fi
}

# Функция для установки Apache
install_apache() {
  echo -e "\033[32mУстанавливаем Apache...\033[0m"
  apt update && apt install -y apache2
  systemctl enable apache2
  systemctl start apache2
  echo -e "\033[32mApache успешно установлен.\033[0m"
}

# Функция для открытия портов
open_ports() {
  echo -e "\033[34mОткрываем порты 80 и 443...\033[0m"
  ufw allow 80
  ufw allow 443
  echo -e "\033[34mПорты 80 и 443 открыты.\033[0m"
}

# Функция для создания файла index.php
create_index_php() {
  local ip_address=$1
  echo -e "\033[36mСоздаём файл index.php...\033[0m"
  cat > /var/www/html/index.php <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>IP Information</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            color: #333;
            text-align: center;
            padding: 50px;
        }
        form {
            margin: 20px auto;
            padding: 20px;
            border: 1px solid #ccc;
            background-color: #fff;
            width: 300px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        label {
            font-weight: bold;
        }
        input {
            margin: 10px 0;
            padding: 10px;
            width: calc(100% - 20px);
            border: 1px solid #ccc;
            border-radius: 5px;
        }
        button {
            background-color: #007bff;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        button:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <h1>IP Information Panel</h1>
    <?php
    if (isset($_POST['ip'])) {
        $input = htmlspecialchars($_POST['ip']);
        $info = file_get_contents("http://ip-api.com/json/" . $input);
        echo "<pre>$info</pre>";
    } else {
        echo "<form method='POST'>
                <label for='ip'>Введите IP или URL:</label>
                <input type='text' id='ip' name='ip' required>
                <button type='submit'>Отправить</button>
              </form>";
    }
    ?>
</body>
</html>
EOL
  chown www-data:www-data /var/www/html/index.php
  chmod 644 /var/www/html/index.php
  echo -e "\033[36mФайл index.php создан.\033[0m"
}

# Функция для создания команды warh
create_warh_command() {
  echo -e "\033[36mСоздаём команду warh...\033[0m"
  cat > /usr/local/bin/warh <<EOL
#!/bin/bash

# Вывод информации о системе
cpu_info=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ':' -f2 | xargs)
memory_info=$(free -h | grep Mem | awk '{print $2" total, "$3" used, "$4" free"}')
disk_info=$(df -h / | grep / | awk '{print $2" total, "$3" used, "$4" free"}')
ip_info=$(hostname -I | awk '{print $1}')
location_info=$(curl -s http://ip-api.com/json/\$ip_info | jq '.country + ", " + .city')

cat <<EOF
\033[34m=== Информация о системе ===\033[0m
Процессор: $cpu_info
Оперативная память: $memory_info
Диск: $disk_info
IP-адрес: $ip_info
Расположение: $location_info
EOF
EOL
  chmod +x /usr/local/bin/warh
  echo -e "\033[36mКоманда warh создана.\033[0m"
}

# Функция для создания команды wip
create_wip_command() {
  echo -e "\033[36mСоздаём команду wip...\033[0m"
  cat > /usr/local/bin/wip <<EOL
#!/bin/bash

if [ -z "$1" ]; then
  echo -e "\033[31mПожалуйста, укажите IP-адрес.\033[0m"
  exit 1
fi

status_code=$(curl -o /dev/null -s -w "%{http_code}" http://$1)

echo -e "\033[34mHTTP статус для $1: $status_code\033[0m"
EOL
  chmod +x /usr/local/bin/wip
  echo -e "\033[36mКоманда wip создана.\033[0m"
}

# Проверка root прав
check_root

# Приветствие
echo -e "\033[35mДобро пожаловать в установщик панели!\033[0m"
echo "Этот скрипт поможет вам установить панель управления IP."
echo "---------------------------------------------------"

# Установка Apache
read -p "Установить Apache? (y/n): " install_apache_choice
if [ "$install_apache_choice" == "y" ]; then
  install_apache
else
  echo -e "\033[33mПропущена установка Apache.\033[0m"
fi

# Открытие портов
read -p "Открыть порты 80 и 443? (y/n): " open_ports_choice
if [ "$open_ports_choice" == "y" ]; then
  open_ports
else
  echo -e "\033[33mПропущено открытие портов.\033[0m"
fi

# Запрос IP адреса панели
read -p "Введите IP-адрес панели: " panel_ip

# Проверка корректности ввода IP
if [[ ! "$panel_ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo -e "\033[31mНекорректный IP-адрес. Скрипт завершён.\033[0m"
  exit 1
fi

# Создание index.php
create_index_php "$panel_ip"

# Создание команд warh и wip
create_warh_command
create_wip_command

echo -e "\033[32mПанель установлена. Перейдите по адресу: http://$panel_ip\033[0m"
