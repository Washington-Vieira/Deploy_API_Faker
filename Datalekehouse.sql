-- =========================================================
-- CRIAÇÃO DOS SCHEMAS DO DATA LAKEHOUSE
-- =========================================================
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS etl;

-- =========================================================
--  CAMADA BRONZE - DADOS BRUTOS (SINGLE TABLE DESIGN)
-- =========================================================
-- Uma única tabela para todos os dados brutos com particionamento por entidade

CREATE TABLE IF NOT EXISTS bronze.dados_brutos (
    id BIGSERIAL,
    entidade TEXT NOT NULL,
    dados JSONB NOT NULL,
    carregado_em TIMESTAMP DEFAULT NOW(),
    hash_dados TEXT GENERATED ALWAYS AS (MD5(dados::TEXT)) STORED,
    PRIMARY KEY (id, entidade)
) PARTITION BY LIST (entidade);

-- Criar partições para cada entidade
CREATE TABLE IF NOT EXISTS bronze.fornecedores PARTITION OF bronze.dados_brutos
    FOR VALUES IN ('fornecedores');

CREATE TABLE IF NOT EXISTS bronze.produtos PARTITION OF bronze.dados_brutos
    FOR VALUES IN ('produtos');

CREATE TABLE IF NOT EXISTS bronze.vendas PARTITION OF bronze.dados_brutos
    FOR VALUES IN ('vendas');

CREATE TABLE IF NOT EXISTS bronze.estoque_atual PARTITION OF bronze.dados_brutos
    FOR VALUES IN ('estoque_atual');

CREATE TABLE IF NOT EXISTS bronze.estoque_historico PARTITION OF bronze.dados_brutos
    FOR VALUES IN ('estoque_historico');

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_bronze_entidade ON bronze.dados_brutos(entidade);
CREATE INDEX IF NOT EXISTS idx_bronze_carregado_em ON bronze.dados_brutos(carregado_em DESC);
CREATE INDEX IF NOT EXISTS idx_bronze_hash ON bronze.dados_brutos(hash_dados);
CREATE INDEX IF NOT EXISTS idx_bronze_dados_gin ON bronze.dados_brutos USING GIN (dados);

-- =========================================================
--  CAMADA SILVER - DADOS TRATADOS E NORMALIZADOS
-- =========================================================

-- Fornecedores
CREATE TABLE IF NOT EXISTS silver.fornecedores (
    fornecedor_id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    cnpj TEXT,
    cidade TEXT,
    estado TEXT,
    pais TEXT,
    data_cadastro TIMESTAMP,
    carregado_em TIMESTAMP DEFAULT NOW(),
    atualizado_em TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_silver_fornecedores_cnpj ON silver.fornecedores(cnpj);
CREATE INDEX IF NOT EXISTS idx_silver_fornecedores_estado ON silver.fornecedores(estado);

-- Produtos
CREATE TABLE IF NOT EXISTS silver.produtos (
    produto_id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    categoria TEXT,
    preco NUMERIC(12,2),
    fornecedor_id TEXT,
    data_cadastro TIMESTAMP,
    carregado_em TIMESTAMP DEFAULT NOW(),
    atualizado_em TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_fornecedor FOREIGN KEY (fornecedor_id) 
        REFERENCES silver.fornecedores(fornecedor_id) 
        ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_silver_produtos_categoria ON silver.produtos(categoria);
CREATE INDEX IF NOT EXISTS idx_silver_produtos_fornecedor ON silver.produtos(fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_silver_produtos_preco ON silver.produtos(preco);

-- Vendas (com particionamento por data)
CREATE TABLE IF NOT EXISTS silver.vendas (
    venda_id TEXT NOT NULL,
    data_venda DATE NOT NULL,
    produto_id TEXT,
    quantidade INT,
    valor_unitario NUMERIC(12,2),
    valor_total NUMERIC(14,2),
    cliente TEXT,
    carregado_em TIMESTAMP DEFAULT NOW(),
    atualizado_em TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (venda_id, data_venda),
    CONSTRAINT fk_produto FOREIGN KEY (produto_id) 
        REFERENCES silver.produtos(produto_id) 
        ON DELETE SET NULL
) PARTITION BY RANGE (data_venda);

-- Partições de vendas (últimos 3 anos + futuro)
CREATE TABLE IF NOT EXISTS silver.vendas_2023 PARTITION OF silver.vendas
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS silver.vendas_2024 PARTITION OF silver.vendas
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS silver.vendas_2025 PARTITION OF silver.vendas
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS silver.vendas_2026 PARTITION OF silver.vendas
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_silver_vendas_data ON silver.vendas(data_venda DESC);
CREATE INDEX IF NOT EXISTS idx_silver_vendas_produto ON silver.vendas(produto_id);
CREATE INDEX IF NOT EXISTS idx_silver_vendas_cliente ON silver.vendas(cliente);

-- Estoque Atual
CREATE TABLE IF NOT EXISTS silver.estoque_atual (
    produto_id TEXT PRIMARY KEY,
    quantidade INT DEFAULT 0,
    quantidade_minima INT,
    quantidade_maxima INT,
    local TEXT,
    carregado_em TIMESTAMP DEFAULT NOW(),
    atualizado_em TIMESTAMP DEFAULT NOW(),
    CONSTRAINT fk_produto_estoque FOREIGN KEY (produto_id) 
        REFERENCES silver.produtos(produto_id) 
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_silver_estoque_local ON silver.estoque_atual(local);
CREATE INDEX IF NOT EXISTS idx_silver_estoque_quantidade ON silver.estoque_atual(quantidade);

-- Estoque Histórico (com particionamento por data)
CREATE TABLE IF NOT EXISTS silver.estoque_historico (
    id BIGSERIAL NOT NULL,
    produto_id TEXT NOT NULL,
    data_movimento DATE NOT NULL,
    quantidade INT,
    tipo_movimento TEXT CHECK (tipo_movimento IN ('entrada', 'saida', 'ajuste', 'transferencia')),
    origem TEXT,
    destino TEXT,
    motivo TEXT,
    carregado_em TIMESTAMP DEFAULT NOW(),
    atualizado_em TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, data_movimento)
) PARTITION BY RANGE (data_movimento);

-- Partições de estoque histórico
CREATE TABLE IF NOT EXISTS silver.estoque_historico_2023 PARTITION OF silver.estoque_historico
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');

CREATE TABLE IF NOT EXISTS silver.estoque_historico_2024 PARTITION OF silver.estoque_historico
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE IF NOT EXISTS silver.estoque_historico_2025 PARTITION OF silver.estoque_historico
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE IF NOT EXISTS silver.estoque_historico_2026 PARTITION OF silver.estoque_historico
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_silver_estoque_hist_produto ON silver.estoque_historico(produto_id);
CREATE INDEX IF NOT EXISTS idx_silver_estoque_hist_data ON silver.estoque_historico(data_movimento DESC);
CREATE INDEX IF NOT EXISTS idx_silver_estoque_hist_tipo ON silver.estoque_historico(tipo_movimento);

-- =========================================================
--  CAMADA GOLD - VISÕES MATERIALIZADAS E AGREGAÇÕES
-- =========================================================

-- Vendas por Produto (Materializada - atualiza sob demanda)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.vendas_por_produto AS
SELECT 
    p.produto_id,
    p.nome AS produto,
    p.categoria,
    COUNT(DISTINCT v.venda_id) AS total_vendas,
    SUM(v.quantidade) AS total_unidades_vendidas,
    SUM(v.valor_total) AS faturamento_total,
    AVG(v.valor_unitario) AS ticket_medio,
    MIN(v.data_venda) AS primeira_venda,
    MAX(v.data_venda) AS ultima_venda,
    NOW() AS atualizado_em
FROM silver.produtos p
LEFT JOIN silver.vendas v ON p.produto_id = v.produto_id
GROUP BY p.produto_id, p.nome, p.categoria;

CREATE UNIQUE INDEX ON gold.vendas_por_produto(produto_id);

-- Vendas por Período (Materializada)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.vendas_por_periodo AS
SELECT 
    DATE_TRUNC('month', data_venda) AS mes,
    COUNT(DISTINCT venda_id) AS total_vendas,
    SUM(quantidade) AS total_unidades,
    SUM(valor_total) AS faturamento,
    AVG(valor_total) AS ticket_medio,
    COUNT(DISTINCT cliente) AS clientes_unicos,
    COUNT(DISTINCT produto_id) AS produtos_vendidos,
    NOW() AS atualizado_em
FROM silver.vendas
GROUP BY DATE_TRUNC('month', data_venda);

CREATE UNIQUE INDEX ON gold.vendas_por_periodo(mes);

-- Resumo de Estoque (Materializada)
CREATE MATERIALIZED VIEW IF NOT EXISTS gold.estoque_resumo AS
SELECT 
    p.produto_id,
    p.nome AS produto,
    p.categoria,
    p.preco,
    COALESCE(ea.quantidade, 0) AS estoque_atual,
    COALESCE(ea.quantidade_minima, 0) AS estoque_minimo,
    COALESCE(ea.quantidade_maxima, 0) AS estoque_maximo,
    CASE 
        WHEN COALESCE(ea.quantidade, 0) <= COALESCE(ea.quantidade_minima, 0) THEN 'CRÍTICO'
        WHEN COALESCE(ea.quantidade, 0) <= COALESCE(ea.quantidade_minima, 0) * 1.5 THEN 'BAIXO'
        WHEN COALESCE(ea.quantidade, 0) >= COALESCE(ea.quantidade_maxima, 0) THEN 'EXCESSO'
        ELSE 'NORMAL'
    END AS status_estoque,
    COALESCE(ea.quantidade, 0) * p.preco AS valor_estoque,
    ea.local,
    NOW() AS atualizado_em
FROM silver.produtos p
LEFT JOIN silver.estoque_atual ea ON p.produto_id = ea.produto_id;

CREATE UNIQUE INDEX ON gold.estoque_resumo(produto_id);

-- Top Produtos Mais Vendidos (View simples - sempre atualizada)
CREATE OR REPLACE VIEW gold.top_produtos_vendidos AS
SELECT 
    produto,
    categoria,
    total_unidades_vendidas,
    faturamento_total,
    ticket_medio,
    ultima_venda
FROM gold.vendas_por_produto
WHERE total_vendas > 0
ORDER BY total_unidades_vendidas DESC
LIMIT 50;

-- Análise de Fornecedores (View simples)
CREATE OR REPLACE VIEW gold.analise_fornecedores AS
SELECT 
    f.fornecedor_id,
    f.nome AS fornecedor,
    f.cidade,
    f.estado,
    COUNT(DISTINCT p.produto_id) AS total_produtos,
    COALESCE(SUM(v.total_vendas), 0) AS total_vendas,
    COALESCE(SUM(v.faturamento_total), 0) AS faturamento_total
FROM silver.fornecedores f
LEFT JOIN silver.produtos p ON f.fornecedor_id = p.fornecedor_id
LEFT JOIN gold.vendas_por_produto v ON p.produto_id = v.produto_id
GROUP BY f.fornecedor_id, f.nome, f.cidade, f.estado;

-- =========================================================
--  CAMADA ETL - LOGS E CONTROLE
-- =========================================================

CREATE TABLE IF NOT EXISTS etl.logs_etl (
    id BIGSERIAL PRIMARY KEY,
    entidade TEXT NOT NULL,
    endpoint_url TEXT,
    inicio_execucao TIMESTAMP NOT NULL,
    fim_execucao TIMESTAMP,
    duracao_ms BIGINT,
    registros_processados INT DEFAULT 0,
    registros_novos INT DEFAULT 0,
    registros_atualizados INT DEFAULT 0,
    registros_com_erro INT DEFAULT 0,
    status_final TEXT CHECK (status_final IN ('sucesso', 'erro', 'parcial')),
    descricao_maxima TEXT,
    erro_detalhe TEXT,
    criado_em TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_etl_logs_entidade ON etl.logs_etl(entidade);
CREATE INDEX IF NOT EXISTS idx_etl_logs_inicio ON etl.logs_etl(inicio_execucao DESC);
CREATE INDEX IF NOT EXISTS idx_etl_logs_status ON etl.logs_etl(status_final);

-- Tabela de controle de execução (evita processamentos duplicados)
CREATE TABLE IF NOT EXISTS etl.controle_execucao (
    id BIGSERIAL PRIMARY KEY,
    entidade TEXT NOT NULL,
    hash_execucao TEXT NOT NULL,
    executado_em TIMESTAMP DEFAULT NOW(),
    UNIQUE(entidade, hash_execucao)
);

CREATE INDEX IF NOT EXISTS idx_etl_controle_entidade ON etl.controle_execucao(entidade);
CREATE INDEX IF NOT EXISTS idx_etl_controle_executado ON etl.controle_execucao(executado_em DESC);

-- =========================================================
--  FUNÇÕES AUXILIARES
-- =========================================================

-- Função para refresh das materialized views da camada Gold
CREATE OR REPLACE FUNCTION gold.refresh_all_views()
RETURNS TEXT AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY gold.vendas_por_produto;
    REFRESH MATERIALIZED VIEW CONCURRENTLY gold.vendas_por_periodo;
    REFRESH MATERIALIZED VIEW CONCURRENTLY gold.estoque_resumo;
    RETURN 'Views atualizadas com sucesso em ' || NOW();
END;
$$ LANGUAGE plpgsql;

-- Função para limpar dados antigos do Bronze (manter últimos 90 dias)
CREATE OR REPLACE FUNCTION bronze.limpar_dados_antigos(dias_manter INT DEFAULT 90)
RETURNS TEXT AS $$
DECLARE
    registros_deletados INT;
BEGIN
    DELETE FROM bronze.dados_brutos 
    WHERE carregado_em < NOW() - (dias_manter || ' days')::INTERVAL;
    
    GET DIAGNOSTICS registros_deletados = ROW_COUNT;
    
    RETURN 'Deletados ' || registros_deletados || ' registros anteriores a ' || 
           (NOW() - (dias_manter || ' days')::INTERVAL);
END;
$$ LANGUAGE plpgsql;

-- Função para criar partições automaticamente (vendas futuras)
CREATE OR REPLACE FUNCTION silver.criar_particao_vendas(ano INT)
RETURNS TEXT AS $$
DECLARE
    nome_tabela TEXT;
    data_inicio DATE;
    data_fim DATE;
BEGIN
    nome_tabela := 'vendas_' || ano;
    data_inicio := (ano || '-01-01')::DATE;
    data_fim := ((ano + 1) || '-01-01')::DATE;
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS silver.%I PARTITION OF silver.vendas
         FOR VALUES FROM (%L) TO (%L)',
        nome_tabela, data_inicio, data_fim
    );
    
    RETURN 'Partição ' || nome_tabela || ' criada com sucesso';
END;
$$ LANGUAGE plpgsql;

-- =========================================================
--  VIEWS DE MONITORAMENTO
-- =========================================================

-- View para monitorar ETL
CREATE OR REPLACE VIEW etl.monitor_execucoes AS
SELECT 
    entidade,
    COUNT(*) AS total_execucoes,
    SUM(CASE WHEN status_final = 'sucesso' THEN 1 ELSE 0 END) AS sucessos,
    SUM(CASE WHEN status_final = 'erro' THEN 1 ELSE 0 END) AS erros,
    AVG(duracao_ms) AS duracao_media_ms,
    MAX(fim_execucao) AS ultima_execucao,
    SUM(registros_processados) AS total_registros
FROM etl.logs_etl
WHERE inicio_execucao >= NOW() - INTERVAL '7 days'
GROUP BY entidade
ORDER BY ultima_execucao DESC;

-- View para alertas de estoque
CREATE OR REPLACE VIEW gold.alertas_estoque AS
SELECT 
    produto_id,
    produto,
    categoria,
    estoque_atual,
    estoque_minimo,
    status_estoque,
    valor_estoque,
    local
FROM gold.estoque_resumo
WHERE status_estoque IN ('CRÍTICO', 'BAIXO', 'EXCESSO')
ORDER BY 
    CASE status_estoque 
        WHEN 'CRÍTICO' THEN 1 
        WHEN 'BAIXO' THEN 2 
        ELSE 3 
    END;

-- =========================================================
--  COMENTÁRIOS NAS TABELAS
-- =========================================================

COMMENT ON SCHEMA bronze IS 'Camada Bronze - Dados brutos em formato JSON';
COMMENT ON SCHEMA silver IS 'Camada Silver - Dados limpos e normalizados';
COMMENT ON SCHEMA gold IS 'Camada Gold - Agregações e métricas de negócio';
COMMENT ON SCHEMA etl IS 'Camada ETL - Logs e controle de execução';

COMMENT ON TABLE bronze.dados_brutos IS 'Tabela particionada que armazena todos os dados brutos recebidos das APIs';
COMMENT ON TABLE etl.logs_etl IS 'Registra todas as execuções do pipeline ETL';
COMMENT ON TABLE etl.controle_execucao IS 'Previne processamento duplicado através de hash';