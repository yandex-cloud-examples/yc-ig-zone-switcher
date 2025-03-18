# В погоне за лидером

Пример описывает вариант использования облачной функции для "слежения" за MDB мастером.
Под слежением здесь понимаем управление атрибутами Yandex Cloud Instance Group таким образом, чтобы ВМ с "пишушей" нагрузкой всегда были в зоне мастера. Такие требования зачастую накладываются на приложения в высокой интенсивностью взаимодействия между сервером приложения и базой данных 
в данном примере - Managed Service for PostgreSQL. Но ничего не помешает подобную функцию использовать и для Managed MySQL. Но, данный пример этот вариант не закрывает.


Итак, из чего состоит пример

- тестовое приложение, генерирующее нагрузку, схожую нагрузкой из [1С-Битрикс "Монитор производительности"](https://www.1c-bitrix.ru/products/cms/modules/productive/)

- Terraform конфигурация, которая создает
  - Необходимую для тестирования инфраструктуру:
     - сеть, подсети, группы безопасности и пр
  - Managed Service for PostgreSQL
  - Instance Group с тестовым приложением
  - Application Load Balancer для балансировки запросов на ВМ Instance Group
  - Функцию переключения зоны для Instance Group
  - Таймер, запускающий функцию из предыдущего пункта раз в 5 минут


Для развертывания конфигурации нужно склонировать проект, положить в него файл terraform.tfvars с заполненными параметрами, которые соответствуют Вашему облаку 

```json
    yc_cloud_id  = "your_cloud_id"
    yc_folder_id = "your_folder_id"
    pg_cluster = {
    db_user = "your_db_user"
    db_pass = "your_db_user_password"
    }
    ssh_key_path = "pass_to_public_key"
    log_group_id = "your_log_group_id"
```

Получить IAM токен
```bash
export TF_VAR_yc_token=$(yc iam create-token)
```

Проиницализировать terraform и применить конфигурацию 
```bash
terraform init
terraform apply
```


Скорость работы тестового приложения после выполнения terraform apply
```bash
watch curl -s http://<your_output_alb_external_ip>/api/status
```

```bash
Every 2.0s: curl -s http://84.201.170.12/api/status                                                            kspoluektov-osx: Tue Mar  4 18:41:29 2025

{select=2083 operations per second at 15:41:29.313765, host=4ef71af1c328, insert=150 operations per second at 15:41:29.978649, update=151 operations
per second at 15:41:29.264949}
```

Смотрим статистику работы сервера приложений
 - скорость выборки по ключу - более 2 операций в секунду
 - скорость вставки и изменения - около 150 

Производим переключение мастера
```bash
yc postgres cluster start-failover --id <your_output_mdb_cluster_id>
```

Скорость работы с базой резко падает 
```bash
Every 2.0s: curl -s http://84.201.170.12/api/status                                                            kspoluektov-osx: Tue Mar  4 18:46:11 2025

{select=261 operations per second at 15:46:11.357227, host=18bfc6d0e282, insert=138 operations per second at 15:46:10.335967, update=156 operations p
er second at 15:46:10.975641}
```

В течение пяти минут функция отследит факт расхождения зоны между Instance Group и Managed Service и сменит зону для Instance Group (смену мы можем отследить в записях лог-группы - там появится сообщение "Instance group has been updated"). Параметры управления деплоем последней плавно пересоздадут ВМ без потери доступности и в скором времени мы увидим прежнюю скорость работы приложения с базой

```bash
Every 2.0s: curl -s http://84.201.170.12/api/status                                                            kspoluektov-osx: Tue Mar  4 18:51:10 2025

{select=2439 operations per second at 15:51:09.188837, host=a4eae84482dd, insert=126 operations per second at 15:51:09.979863, update=165 operations
per second at 15:51:09.147909}
```