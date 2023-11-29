# VVOT homework #1

## Гусев Фёдор, 11-002

### Описание:

В репозитории размещены все файлы, необходимые для проверки работоспособности домашнего задания:

`main.tf` - Основная логика работы Terraform, описание всех компонентов и их конфигураций.

`variables.tf` - Перечисление переменных, а также указание некоторых значений по-умолчанию. При необходимости, этот файл можно изменить. Параметры:
* "admin_id" - (Обязательный для ввода) Идентификатор сервисного аккаунта с ролью `admin` (или набором ролей `storage.editor`, `ydb.editor`, `ai.vision.user`, `serverless.functions.invoker`, `editor`). В случае окружения, где проводилось тестирование, равен `ajecf18bgu9pi0lllm7b`.
* "clound_id" - (Обязательный для ввода) Идентификатор облака. В случае окружения, где проводилось тестирование, равен `b1g71e95h51okii30p25`.
* "folder_id" - (Обязательный для ввода) Идентификатор директории. В случае окружения, где проводилось тестирование, равен `b1gthpeliup6ofmutirb`.
* "iam_token" - (Обязательный для ввода) IAM токен, полученный для аккаунта.
* "tgkey" - (Обязательный для ввода) Секретный ключ бота, с которым будет проводиться тестирование.
* "aws_region" - Регион для S3. По-умолчанию равен `ru-central1`. Может быть изменён вручную.
* "zone_region" - Регион вычислений. По-умолчанию равен `ru-central1-a`. Может быть изменён вручную.  

`hardcode-values.txt` - Список значений, которые были использованы в тестовой среде.

`key.json` - Файл доступа для указанного сервисного аккаунта. Не представлен в репозитории, должен быть добавлен вручную.

Директория `face-detection` - логика обработки появления нового .jpg изображения, получение координат лиц.

Директория `face-cut` - логика обрезки и сохранения обработанных файлов.

Директория `bot` - логика обработки сообщений телеграм бота.

### Детали:

* Иногда установка бакетов занимает 2 минуты. Не удалось выяснить, с чем это связано.

* Невозможно создать функцию с именем `vvot00_2023_boot`, как указано в задании. В соответствии с правилами синтаксиса имён функций имя было изменено на `vvot00-2023-boot`.

* При использовании в Api Gateway в качестве параметра `face` только ключа файла (т.е. random uuid) невозможно получить на скачивание файл с необходимым расширением. Поэтому в параметре запроса `face` используется так-же суффикс `.jpg`.

* В бота добавлена команда `/help` для получения дополнительной справки.