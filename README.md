# Lesson 10 — MLOps Train Automation

Автоматизація тренування моделей через AWS Step Functions + Lambda, розгорнута через Terraform з інтеграцією GitLab CI.

## Конфігурація за замовчуванням

AWS-налаштування взяті з попередніх GoIT DevOps проєктів: локальний Terraform використовує профіль `devops` з `~/.aws/config` / `~/.aws/credentials`, а регіон — `us-east-1`. Значення `AWS_ACCESS_KEY_ID` та `AWS_SECRET_ACCESS_KEY` не зберігаються в репозиторії; для GitLab CI їх потрібно додати як masked/protected CI variables з того самого AWS профілю.

| Параметр | Значення |
| --- | --- |
| AWS Region | `us-east-1` |
| AWS Profile | `devops` |
| Validate Lambda | `mlops-validate` |
| Log Metrics Lambda | `mlops-log-metrics` |
| Step Function | `mlops-train-pipeline` |
| Lambda Runtime | `python3.12` |

## Архітектура

```text
GitLab CI (push) → aws stepfunctions start-execution
                          ↓
              Step Function: mlops-train-pipeline
                          ↓
              Step 1: ValidateData  (Lambda: mlops-validate)
                          ↓
              Step 2: LogMetrics    (Lambda: mlops-log-metrics)
```

## Структура проєкту

```text
mlops-train-automation/
├── terraform/
│   ├── main.tf          # IAM ролі, Lambda, Step Function
│   ├── variables.tf
│   └── lambda/
│       ├── validate.py
│       ├── log_metrics.py
│       ├── validate.zip
│       └── log_metrics.zip
├── .gitlab-ci.yml
└── README.md
```

## Передумови

| Інструмент | Версія |
| --- | --- |
| Terraform | >= 1.3 |
| AWS CLI | >= 2 |
| Python | >= 3.12 |
| zip | будь-яка |

## 1. Зібрати Lambda-архіви

```bash
cd terraform/lambda
zip validate.zip validate.py
zip log_metrics.zip log_metrics.py
```

## 2. Розгорнути інфраструктуру через Terraform

```bash
cd terraform
terraform init
terraform apply
```

Terraform створить:

- IAM роль для Lambda (`mlops-lambda-execution-role`)
- IAM роль для Step Functions (`mlops-step-function-role`) з дозволом на виклик Lambda
- Lambda-функції `mlops-validate` та `mlops-log-metrics`
- Step Function `mlops-train-pipeline` з двома кроками: `ValidateData → LogMetrics`

Після завершення `terraform apply` виведе ARN стейт-машини:

```text
Outputs:
state_machine_arn = "arn:aws:states:us-east-1:123456789012:stateMachine:mlops-train-pipeline"
```

## 3. Вручну перевірити Step Function через AWS Console

1. Відкрити [AWS Console → Step Functions](https://console.aws.amazon.com/states/)
2. Знайти `mlops-train-pipeline`
3. Натиснути **Start execution**
4. Передати JSON:

```json
{
  "source": "manual",
  "commit": "abc123"
}
```

1. Перевірити, що обидва стани (`ValidateData` та `LogMetrics`) виконались зі статусом **Succeeded**
1. Логи Lambda доступні в **CloudWatch Logs** → `/aws/lambda/mlops-validate` та `/aws/lambda/mlops-log-metrics`

## 4. GitLab CI

### Як працює job

Файл `.gitlab-ci.yml` містить один job `train-model` на стадії `train`. При кожному `push` до репозиторію GitLab CI:

1. Запускає контейнер `amazon/aws-cli:2.15.0`
2. Виконує `aws stepfunctions start-execution` з унікальним іменем `train-<timestamp>`
3. Передає JSON з джерелом та SHA коміту

### Необхідні змінні в GitLab CI Settings

| Змінна | Значення |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Access key з локального AWS профілю `devops` |
| `AWS_SECRET_ACCESS_KEY` | Secret key з локального AWS профілю `devops` |
| `AWS_DEFAULT_REGION` | `us-east-1` (також задано у `.gitlab-ci.yml`) |
| `STATE_MACHINE_ARN` | ARN з виводу `terraform apply` |

Додати через: **Settings → CI/CD → Variables**

### Приклад JSON, що передається через CI

```json
{
  "source": "gitlab-ci",
  "commit": "a1b2c3d4"
}
```

де `commit` — значення змінної `$CI_COMMIT_SHORT_SHA` (перші 8 символів SHA коміту).
