from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
from faker import Faker
import random
from datetime import datetime

# Definindo localidade para Português do Brasil
fake = Faker('pt_BR')

# --- DEFINIÇÃO DOS PRODUTOS MOCKADOS PARA VAREJO ---
PRODUTOS_MOCK = [
    # Alimentos Básicos
    ("Arroz Integral 5kg", "Alimentos", "Grãos e Cereais"),
    ("Feijão Carioca Tipo 1", "Alimentos", "Grãos e Cereais"),
    ("Açúcar Refinado 1kg", "Alimentos", "Mercearia"),
    ("Café Torrado e Moído 500g", "Alimentos", "Mercearia"),
    ("Óleo de Soja 900ml", "Alimentos", "Mercearia"),

    # Carnes e Perecíveis (Simulados como itens de alto valor)
    ("Picanha Maturada Kg", "Alimentos", "Açougue"),
    ("Filé de Frango Congelado 1kg", "Alimentos", "Congelados"),
    ("Salmão Fresco Posta Kg", "Alimentos", "Açougue"),

    # Laticínios e Frios
    ("Leite Integral UHT 1L", "Alimentos", "Laticínios"),
    ("Queijo Muçarela Fatiado 150g", "Alimentos", "Frios"),
    ("Iogurte Natural 170g", "Alimentos", "Laticínios"),

    # Bebidas
    ("Água Mineral Sem Gás 1.5L", "Bebidas", "Não Alcoólicas"),
    ("Refrigerante Cola 2L", "Bebidas", "Não Alcoólicas"),
    ("Cerveja Pilsen Lata 350ml (Pack c/ 12)", "Bebidas", "Alcoólicas"),
    ("Vinho Tinto Seco Chileno", "Bebidas", "Alcoólicas"),

    # Limpeza
    ("Detergente Neutro 500ml", "Limpeza", "Cozinha"),
    ("Álcool Líquido 70% 1L", "Limpeza", "Multiuso"),
    ("Sabão em Pó 2kg", "Limpeza", "Lavanderia"),
    ("Lã de Aço", "Limpeza", "Acessórios"),

    # Higiene Pessoal
    ("Shampoo Cabelos Normais 300ml", "Higiene Pessoal", "Cuidados Capilares"),
    ("Creme Dental Menta 90g", "Higiene Pessoal", "Cuidados Bucais"),
    ("Sabonete em Barra (Pack c/ 4)", "Higiene Pessoal", "Banho"),
    ("Desodorante Aerossol", "Higiene Pessoal", "Corpo"),

    # Eletrônicos (Itens de alto valor/baixa rotatividade)
    ("Fone de Ouvido Bluetooth", "Eletrônicos", "Acessórios"),
    ("Smart TV 50 polegadas 4K", "Eletrônicos", "TVs e Vídeo"),
    ("Carregador Portátil 10000mAh", "Eletrônicos", "Acessórios"),

    # Roupas (Têxteis)
    ("Camiseta Básica Algodão", "Roupas", "Vestuário Masculino"),
    ("Calça Jeans Feminina", "Roupas", "Vestuário Feminino"),
    ("Meias Esportivas (Pack c/ 3)", "Roupas", "Acessórios"),
]
# -----------------------------------------------------------------

# --- DEFINIÇÃO DOS MODELOS (INALTERADA) ---
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
# ---------------------------------------------


app = FastAPI()
FORNECEDORES = []
PRODUTOS = []


def setup_dados():
    global FORNECEDORES, PRODUTOS
    
    # 1. Gerar Fornecedores
    FORNECEDORES = [
        Fornecedor(
            fornecedor_id=fake.unique.uuid4(),
            nome=fake.company(),
            cnpj=fake.cnpj(),
            cidade=fake.city(),
            estado=fake.state_abbr(),
            pais=fake.country(),
            data_cadastro=fake.date_time_this_decade()
        ) for _ in range(7) # Aumentei para 7 fornecedores
    ]

    # 2. Gerar Produtos REALISTAS
    PRODUTOS = []
    
    # Gerar os produtos baseados na lista PRODUTOS_MOCK
    for nome, categoria, subcategoria in PRODUTOS_MOCK:
        fornecedor = random.choice(FORNECEDORES)
        
        # Definir preços mais realistas para diferentes categorias
        if categoria == 'Eletrônicos':
            preco_base = random.uniform(500.0, 5000.0)
        elif categoria in ['Roupas', 'Açougue']:
            preco_base = random.uniform(50.0, 300.0)
        elif categoria in ['Bebidas', 'Higiene Pessoal']:
            preco_base = random.uniform(5.0, 50.0)
        else: # Alimentos, Limpeza
            preco_base = random.uniform(2.5, 40.0)
            
        PRODUTOS.append(
            Produto(
                produto_id=fake.unique.uuid4(),
                nome=nome,
                categoria=categoria,
                preco=round(preco_base, 2),
                fornecedor_id=fornecedor.fornecedor_id,
                data_cadastro=fake.date_time_this_decade()
            )
        )
        
    # Garantir que temos no mínimo 30 produtos (se a lista for menor)
    if len(PRODUTOS) < 30:
        for _ in range(30 - len(PRODUTOS)):
             fornecedor = random.choice(FORNECEDORES)
             categoria = random.choice(['Alimentos', 'Bebidas', 'Limpeza', 'Higiene Pessoal', 'Eletrônicos', 'Roupas'])
             PRODUTOS.append(
                Produto(
                    produto_id=fake.unique.uuid4(),
                    nome=fake.word().capitalize() + ' Extra',
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
    # Aumentando o número de vendas por chamada para ter mais dados
    for _ in range(50):
        # Seleção de produtos com maior chance de serem vendidos (não-Eletrônicos)
        produtos_alta_rotatividade = [p for p in PRODUTOS if p.categoria not in ['Eletrônicos', 'Roupas']]
        
        if random.random() < 0.8 and produtos_alta_rotatividade:
            produto = random.choice(produtos_alta_rotatividade)
            quantidade = random.randint(1, 10)
        else:
            produto = random.choice(PRODUTOS)
            quantidade = random.randint(1, 3) # Menos unidades para itens caros

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
        # Estoque mais baixo para Eletrônicos (alto valor) e mais alto para Alimentos/Limpeza
        if produto.categoria == 'Eletrônicos':
            min_q = 2
            max_q = 30
        else:
            min_q = 50
            max_q = 1000
            
        quantidade_minima = random.randint(min_q, max_q // 5)
        quantidade_maxima = random.randint(max_q // 2, max_q)
        quantidade_atual = random.randint(quantidade_minima - 10, quantidade_maxima + 50)
        
        estoque_atual.append(
            EstoqueAtual(
                produto_id=produto.produto_id,
                quantidade=max(0, quantidade_atual), # Garante que não é negativo
                quantidade_minima=quantidade_minima,
                quantidade_maxima=quantidade_maxima
            )
        )
    return estoque_atual

@app.get("/estoque_historico", response_model=List[EstoqueHistorico])
def get_estoque_historico():
    estoque_historico = []
    tipos = ['entrada', 'saida', 'ajuste', 'transferencia']
    
    # Aumentando o histórico gerado
    for i in range(50): 
        produto = random.choice(PRODUTOS)
        
        # Movimentos de estoque mais realistas
        tipo_movimento = random.choice(tipos)
        
        if tipo_movimento == 'entrada':
            q = random.randint(50, 300)
            origem = random.choice(['CD Principal', 'Fornecedor X', 'Fornecedor Y'])
            destino = 'Loja Central'
        elif tipo_movimento == 'saida':
            q = random.randint(10, 150)
            origem = 'Loja Central'
            destino = 'Venda Diária'
        else:
            q = random.randint(1, 50)
            origem = fake.city()
            destino = fake.city()
            
        estoque_historico.append(
            EstoqueHistorico(
                id=i+1,
                produto_id=produto.produto_id,
                data_movimento=fake.date_time_this_year(),
                quantidade=q,
                tipo_movimento=tipo_movimento,
                origem=origem,
                destino=destino,
                motivo=fake.sentence(nb_words=6)
            )
        )
    return estoque_historico