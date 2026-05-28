# Lesson 10 — MLOps Train Automation

Автоматизація тренування моделей через AWS Step Functions + Lambda, розгорнута через Terraform з інтеграцією GitHub Actions.

## Конфігурація за замовчуванням

AWS-налаштування взяті з попередніх GoIT DevOps проєктів: локальний Terraform використовує профіль `devops` з `~/.aws/config` / `~/.aws/credentials`, а регіон — `us-east-1`. Значення `AWS_ACCESS_KEY_ID` та `AWS_SECRET_ACCESS_KEY` не зберігаються в репозиторії; для GitHub Actions їх потрібно додати як repository secrets з того самого AWS профілю.

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
GitHub Actions (push) -> aws stepfunctions start-execution
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
├── .github/
│   └── workflows/
│       └── train-model.yml
└── README.md
```

## Передумови

| Інструмент | Версія |
| --- | --- |
| Terraform | >= 1.3 |
| AWS CLI | >= 2 |
| Python | >= 3.12 |
| zip | будь-яка |

## Зібрати Lambda-архіви

```bash
cd terraform/lambda
zip validate.zip validate.py
zip log_metrics.zip log_metrics.py
```

## Розгорнути інфраструктуру через Terraform

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
Real outputs:
state_machine_arn = "arn:aws:states:us-east-1:716145798329:stateMachine:mlops-train-pipeline"
```

## Вручну перевірити Step Function через AWS Console

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

5. Перевірити, що обидва стани (`ValidateData` та `LogMetrics`) виконались зі статусом **Succeeded**
6. Логи Lambda доступні в **CloudWatch Logs** → `/aws/lambda/mlops-validate` та `/aws/lambda/mlops-log-metrics`
![](./img/mlops-train-pipeline.png)
## 4. GitHub Actions

### Як працює workflow

Файл `.github/workflows/train-model.yml` містить workflow `Train Model`. При кожному `push` до GitHub репозиторію:

1. Запускає job `train-model` на `ubuntu-latest`
2. Налаштовує AWS credentials через `aws-actions/configure-aws-credentials@v4`
3. Виконує `aws stepfunctions start-execution` з унікальним іменем `train-<short-sha>-<timestamp>`
4. Передає JSON з джерелом та SHA коміту

### Необхідні GitHub Secrets

| Змінна | Значення |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Access key з локального AWS профілю `devops` |
| `AWS_SECRET_ACCESS_KEY` | Secret key з локального AWS профілю `devops` |
| `STATE_MACHINE_ARN` | ARN з виводу `terraform apply` |

Додати через: **Settings -> Secrets and variables -> Actions -> New repository secret**

`AWS_DEFAULT_REGION` задано напряму у workflow як `us-east-1`.

### Приклад JSON, що передається через GitHub Actions

```json
{
  "source": "github-actions",
  "commit": "a1b2c3d4"
}
```

де `commit` — перші 8 символів значення `$GITHUB_SHA`.
