from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from faker import Faker
import random
from datetime import datetime

app = FastAPI()
fake = Faker('pt_BR')

class Fornecedor(BaseModel):
    fornecedor_id: str
    nome: str
    cnpj: str
    cidade: str
    estado: str
    pais: str
    data_cadastro: datetime

class Produto(BaseModel):
    produto_id: str
    nome: str
    categoria: str
    preco: float
    fornecedor_id: str
    data_cadastro: datetime

class Venda(BaseModel):
    venda_id: str
    data_venda: datetime
    produto_id: str
    quantidade: int
    valor_unitario: float
    valor_total: float
    cliente: str

class EstoqueAtual(BaseModel):
    produto_id: str
    quantidade: int
    quantidade_minima: int
    quantidade_maxima: int

class EstoqueHistorico(BaseModel):
    id: int
    produto_id: str
    data_movimento: datetime
    quantidade: int
    tipo_movimento: str
    origem: str
    destino: str
    motivo: str

FORNECEDORES = []
PRODUTOS = []

def setup_dados():
    global FORNECEDORES, PRODUTOS
    FORNECEDORES = [
        Fornecedor(
            fornecedor_id=fake.unique.uuid4(),
            nome=fake.company(),
            cnpj=fake.cnpj(),
            cidade=fake.city(),
            estado=fake.state_abbr(),
            pais=fake.country(),
            data_cadastro=fake.date_time_this_decade()
        ) for _ in range(5)
    ]

    PRODUTOS = []
    for _ in range(20):
        fornecedor = random.choice(FORNECEDORES)
        categoria = random.choice(['Alimentos', 'Bebidas', 'Limpeza', 'Higiene Pessoal', 'Eletrônicos', 'Roupas'])
        PRODUTOS.append(
            Produto(
                produto_id=fake.unique.uuid4(),
                nome=fake.word().capitalize(),
                categoria=categoria,
                preco=round(random.uniform(1.0, 200.0), 2),
                fornecedor_id=fornecedor.fornecedor_id,
                data_cadastro=fake.date_time_this_decade()
            )
        )

setup_dados()

@app.get("/fornecedores", response_model=List[Fornecedor])
def get_fornecedores():
    return FORNECEDORES

@app.get("/produtos", response_model=List[Produto])
def get_produtos():
    return PRODUTOS

@app.get("/vendas", response_model=List[Venda])
def get_vendas():
    vendas = []
    for _ in range(10):
        produto = random.choice(PRODUTOS)
        quantidade = random.randint(1, 20)
        valor_unitario = produto.preco
        vendas.append(
            Venda(
                venda_id=fake.unique.uuid4(),
                data_venda=fake.date_time_this_year(),
                produto_id=produto.produto_id,
                quantidade=quantidade,
                valor_unitario=valor_unitario,
                valor_total=round(valor_unitario * quantidade, 2),
                cliente=fake.name()
            )
        )
    return vendas

@app.get("/estoque_atual", response_model=List[EstoqueAtual])
def get_estoque_atual():
    estoque_atual = []
    for produto in PRODUTOS:
        estoque_atual.append(
            EstoqueAtual(
                produto_id=produto.produto_id,
                quantidade=random.randint(0, 500),
                quantidade_minima=random.randint(10, 50),
                quantidade_maxima=random.randint(100, 500)
            )
        )
    return estoque_atual

@app.get("/estoque_historico", response_model=List[EstoqueHistorico])
def get_estoque_historico():
    estoque_historico = []
    tipos = ['entrada', 'saida', 'ajuste', 'transferencia']
    for i in range(30):
        produto = random.choice(PRODUTOS)
        estoque_historico.append(
            EstoqueHistorico(
                id=i+1,
                produto_id=produto.produto_id,
                data_movimento=fake.date_time_this_year(),
                quantidade=random.randint(1, 100),
                tipo_movimento=random.choice(tipos),
                origem=fake.city(),
                destino=fake.city(),
                motivo=fake.sentence(nb_words=6)
            )
        )
    return estoque_historico
