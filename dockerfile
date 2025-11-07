# Usar imagem oficial leve do Python
FROM python:3.13

# Definir diretório de trabalho
WORKDIR /app

# Copiar requirements e instalar dependências
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copiar o código da API para dentro do container
COPY main.py .

# Expor a porta usada pelo FastAPI
EXPOSE 8000

# Comando para rodar o Uvicorn executando a API
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
