# Deploy_API_Faker

## Sobre
Este repositório contém uma API simples (arquivo `main.py`) que pode ser executada localmente com Uvicorn/Starlette/FastAPI (dependendo do que está em `requirements.txt`) e também pode ser empacotada em um container Docker usando o arquivo `dockerfile` presente na raiz.

O objetivo deste README é reunir todos os passos necessários para rodar a API no Windows (PowerShell) e via Docker.

## Pré-requisitos
- Python 3.11 instalado
- Git (opcional)
- Docker (se for rodar via container)
- `requirements.txt` presente na raiz com as dependências da API

## Estrutura principal
- `main.py` — código da API (ponto de entrada para Uvicorn)
- `requirements.txt` — dependências Python
- `dockerfile` — instruções para criar a imagem Docker

## Executando localmente (Windows PowerShell)

1. Abra o PowerShell na pasta do projeto:

```powershell
cd 'C:\Users\Washington Vieira\Documents\API_simulação'
```

2. Criar e ativar um ambiente virtual (recomendado):

```powershell
python -m venv .venv
# Se sua política de execução bloqueia scripts, permita só para a sessão atual:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
# Ative o venv
.\.venv\Scripts\Activate.ps1
```

3. Instalar dependências:

```powershell
pip install --upgrade pip
pip install -r requirements.txt
```

4. Rodar a API com Uvicorn (modo desenvolvimento com reload):

```powershell
& .\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Observações:
- Usamos `python -m uvicorn` para garantir que o uvicorn do ambiente virtual seja usado.
- Para rodar em background no PowerShell você pode abrir outra janela ou usar `Start-Process`.

5. Testar a API

- Abra no navegador: http://localhost:8000/docs
- Ou usar PowerShell para checar a rota principal:

```powershell
Invoke-RestMethod http://localhost:8000/
# ou verificar /docs:
Invoke-RestMethod http://localhost:8000/docs
```

## Executando com Docker

O arquivo de construção presente tem o nome `dockerfile` (tudo minúsculo). Para garantir que o Docker use esse arquivo, especifique `-f dockerfile` ao construir a imagem.

1. Construir a imagem Docker:

```powershell
docker build -f dockerfile -t deploy_api_faker:latest .
```

2. Rodar o container mapeando a porta 8000:

```powershell
docker run --rm -p 8000:8000 --name deploy_api_faker_container deploy_api_faker:latest
```

Se quiser rodar em background (detached):

```powershell
docker run -d -p 8000:8000 --name deploy_api_faker_container deploy_api_faker:latest
```

3. Verificar a API

- Abra http://localhost:8000/docs no navegador.
- Para ver logs do container em execução:

```powershell
docker logs -f deploy_api_faker_container
```

## Notas importantes e solução de problemas
- Se a porta 8000 já estiver em uso, escolha outra porta e ajuste os comandos (`--port 8080` e `-p 8080:8080`).
- Se receber erro de execução do PowerShell ao ativar o venv, execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` como mostrado acima.
- Se o Docker não construir, verifique se o daemon do Docker está rodando e se você tem permissões para usá-lo.
- O `dockerfile` assume que `requirements.txt` está na mesma pasta. Se adicionar dependências, atualize `requirements.txt` e reconstrua a imagem.

## Atualizar dependências
Depois de instalar novas dependências localmente, gere/atualize o `requirements.txt` com:

```powershell
pip freeze > requirements.txt
```

## Como contribuir
- Abra uma issue descrevendo o que deseja melhorar.
- Para pequenas correções, envie um pull request com a mudança.

## Resumo das ações desta alteração
- Este README foi expandido com instruções completas para execução local e via Docker, comandos PowerShell, verificação e troubleshooting.

---
Arquivo: `main.py` — ponto de entrada; `dockerfile` — usado para criar imagem Docker; `requirements.txt` — dependências.
