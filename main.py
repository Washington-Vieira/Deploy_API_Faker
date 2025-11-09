from fastapi import FastAPI
from faker import Faker
from typing import List
import random
from pydantic import BaseModel
from datetime import datetime


app = FastAPI()
fake = Faker('pt_BR')


categorias_varejo = ['Alimentos', 'Bebidas', 'Limpeza', 'Higiene Pessoal', 'Eletrônicos', 'Roupas']


class Fornecedor(BaseModel):
    id: int
    nome: str
    cnpj: str
    telefone: str
    email: str


class Produto(BaseModel):
    id: int
    descricao: str
    codigo_barra: str
    preco: float
    categoria: str
    fornecedor_id: int


class EstoqueAtual(BaseModel):
    produto_id: int
    quantidade: int
    localizacao: str


class EstoqueHistorico(BaseModel):
    produto_id: int
    quantidade: int
    data_movimento: datetime


class Venda(BaseModel):
    id: int
    produto_id: int
    quantidade: int
    data_venda: datetime
    valor_unitario: float


# Geração fixa para assegurar consistência no relacionamento
FORNECEDORES = []
PRODUTOS = []

def setup_dados():
    global FORNECEDORES, PRODUTOS
    next_id = 1  # contador para ids inteiros únicos
    FORNECEDORES = [
        Fornecedor(
            id=next_id + i,
            nome=fake.company(),
            cnpj=fake.cnpj(),
            telefone=fake.phone_number(),
            email=fake.company_email()
        ) for i in range(5)
    ]
    next_id += len(FORNECEDORES)
    PRODUTOS = []
    for i in range(20):
        fornecedor = random.choice(FORNECEDORES)
        categoria = random.choice(categorias_varejo)
        descricao = f"{fake.word().capitalize()} {categoria}"
        PRODUTOS.append(
            Produto(
                id=next_id + i,
                descricao=descricao,
                codigo_barra=fake.ean(length=13),
                preco=round(random.uniform(1.0, 200.0), 2),
                categoria=categoria,
                fornecedor_id=fornecedor.id
            )
        )


setup_dados()

@app.get("/fornecedores", response_model=List[Fornecedor])
def get_fornecedores():
    return FORNECEDORES

@app.get("/produtos", response_model=List[Produto])
def get_produtos():
    return PRODUTOS

@app.get("/estoque_atual", response_model=List[EstoqueAtual])
def get_estoque_atual():
    estoque_atual = []
    for produto in PRODUTOS:
        estoque_atual.append(
            EstoqueAtual(
                produto_id=produto.id,
                quantidade=random.randint(0, 500),
                localizacao=fake.city()
            )
        )
    return estoque_atual

@app.get("/estoque_historico", response_model=List[EstoqueHistorico])
def get_estoque_historico():
    estoque_historico = []
    for produto in PRODUTOS:
        estoque_historico.append(
            EstoqueHistorico(
                produto_id=produto.id,
                quantidade=random.randint(0, 500),
                data_movimento=fake.date_time_between(start_date='-1y', end_date='now')
            )
        )
    return estoque_historico

@app.get("/vendas", response_model=List[Venda])
def get_vendas():
    vendas = []
    next_id = max([produto.id for produto in PRODUTOS]) + 1
    for i in range(10):
        produto = random.choice(PRODUTOS)
        vendas.append(
            Venda(
                id=next_id + i,
                produto_id=produto.id,
                quantidade=random.randint(1, 20),
                data_venda=fake.date_time_between(start_date='-1y', end_date='now'),
                valor_unitario=produto.preco
            )
        )
    return vendas
