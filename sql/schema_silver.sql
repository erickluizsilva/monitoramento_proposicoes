CREATE SCHEMA IF NOT EXISTS silver;

-- Dados normalizados da proposição em si. Nenhuma regra de negócio aplicada.
CREATE TABLE IF NOT EXISTS silver.proposicao (
    id_proposicao           BIGINT PRIMARY KEY,
    sigla_tipo              VARCHAR(20),
    descricao_tipo          VARCHAR(255),
    numero                  INT,
    ano                     INT,
    ementa                  TEXT,
    data_apresentacao       TIMESTAMP,
    sigla_orgao_atual       VARCHAR(20),
    descricao_situacao      VARCHAR(255),
    descricao_tramitacao    TEXT,
    despacho                TEXT,
    data_ultima_movimentacao TIMESTAMP,
    cod_situacao            INT,
    link_direto             TEXT,
    keywords_camara         TEXT,
    data_extracao           TIMESTAMP
);

-- Relação 1:N proposição -> proponentes. Nem todo proponente é deputado
-- (pode ser órgão do Executivo, comissão etc.) — ver achados_1.txt.
-- Não há partido/UF disponíveis neste endpoint da API.
CREATE TABLE IF NOT EXISTS silver.proposicoes_proponentes (
    id_proposicao    BIGINT NOT NULL REFERENCES silver.proposicao (id_proposicao),
    ordem_assinatura INT NOT NULL,
    uri              TEXT,
    nome             VARCHAR(255),
    tipo             VARCHAR(100),
    cod_tipo         INT,
    proponente       INT,
    data_extracao    TIMESTAMP,
    PRIMARY KEY (id_proposicao, ordem_assinatura)
);

-- Relação N:N proposição -> temas legislativos da Câmara.
CREATE TABLE IF NOT EXISTS silver.proposicao_tema (
    id_proposicao BIGINT NOT NULL REFERENCES silver.proposicao (id_proposicao),
    cod_tema      INT NOT NULL,
    tema          VARCHAR(255),
    relevancia    INT,
    data_extracao TIMESTAMP,
    PRIMARY KEY (id_proposicao, cod_tema)
);

-- Histórico de movimentações. Estrutural: nunca é sobrescrito, só cresce.
CREATE TABLE IF NOT EXISTS silver.tramitacao (
    id_proposicao         BIGINT NOT NULL REFERENCES silver.proposicao (id_proposicao),
    sequencia             INT NOT NULL,
    data_hora             TIMESTAMP,
    sigla_orgao           VARCHAR(20),
    uri_orgao             TEXT,
    cod_situacao          INT,
    descricao_situacao    VARCHAR(255),
    descricao_tramitacao  TEXT,
    despacho              TEXT,
    url                   TEXT,
    cod_tipo_tramitacao   VARCHAR(20),
    data_extracao         TIMESTAMP,
    PRIMARY KEY (id_proposicao, sequencia)
);

-- Tabela de referência: temas legislativos da Câmara.
-- A API só retorna 'cod' e 'nome' preenchidos (sigla/descricao vêm sempre vazios).
CREATE TABLE IF NOT EXISTS silver.dim_tema (
    cod_tema INT PRIMARY KEY,
    nome     VARCHAR(255)
);

-- Dimensão de deputados: partido/UF ATUAIS (ultimoStatus da API /deputados/{id}),
-- não o partido na data em que a proposição foi apresentada. Para deputados fora
-- de mandato, "atual" é o último status que a Câmara registrou, não necessariamente
-- a filiação partidária civil dele hoje. Upsert — sempre reflete o dado mais recente
-- coletado, sem histórico de mudanças de partido (para isso, ver /deputados/{id}/historico).
CREATE TABLE IF NOT EXISTS silver.dim_deputado (
    id_deputado   INT PRIMARY KEY,
    nome          VARCHAR(255),
    sigla_partido VARCHAR(20),
    sigla_uf      VARCHAR(5),
    situacao      VARCHAR(50),
    data_extracao TIMESTAMP
);

-- Tabela de configuração: palavras-chave usadas no matching da gold.
-- 'termo' é o fragmento de regex usado no match (ver src/keywords.py);
-- 'rotulo' é o texto legível exibido nos resultados (ex.: "suínos").
CREATE TABLE IF NOT EXISTS silver.dim_keyword (
    id_keyword SERIAL PRIMARY KEY,
    termo      VARCHAR(100) UNIQUE NOT NULL,
    rotulo     VARCHAR(100) NOT NULL,
    ativo      BOOLEAN NOT NULL DEFAULT true
);
