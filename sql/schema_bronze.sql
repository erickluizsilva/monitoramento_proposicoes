-- Camada bronze: append-only. Cada extração grava uma NOVA linha (nunca
-- update/delete), preservando o histórico de payloads como a API os retornou.
-- A chave primária é um id_bronze surrogate; id_proposicao é indexado, não único.

CREATE SCHEMA IF NOT EXISTS bronze;

CREATE TABLE IF NOT EXISTS bronze.proposicoes_json (
    id_bronze       BIGSERIAL PRIMARY KEY,
    id_proposicao   BIGINT NOT NULL,
    payload         JSONB NOT NULL,
    data_extracao   TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_bronze_proposicoes_json_id_proposicao
    ON bronze.proposicoes_json (id_proposicao);

CREATE TABLE IF NOT EXISTS bronze.autores_json (
    id_bronze       BIGSERIAL PRIMARY KEY,
    id_proposicao   BIGINT NOT NULL,
    payload         JSONB NOT NULL,
    data_extracao   TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_bronze_autores_json_id_proposicao
    ON bronze.autores_json (id_proposicao);

CREATE TABLE IF NOT EXISTS bronze.temas_json (
    id_bronze       BIGSERIAL PRIMARY KEY,
    id_proposicao   BIGINT NOT NULL,
    payload         JSONB NOT NULL,
    data_extracao   TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_bronze_temas_json_id_proposicao
    ON bronze.temas_json (id_proposicao);

CREATE TABLE IF NOT EXISTS bronze.tramitacoes_json (
    id_bronze       BIGSERIAL PRIMARY KEY,
    id_proposicao   BIGINT NOT NULL,
    payload         JSONB NOT NULL,
    data_extracao   TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_bronze_tramitacoes_json_id_proposicao
    ON bronze.tramitacoes_json (id_proposicao);

-- Controle de execução da carga incremental. Guarda a janela [data_inicio_janela,
-- data_fim_janela] de cada run bem-sucedido. O próximo run calcula seu dataInicio
-- como min(hoje - 3, data_fim_janela do último run - 3): se rodou ontem, é
-- equivalente a D-3 fixo; se ficou N dias sem rodar, a janela se alarga sozinha
-- para cobrir o buraco inteiro, sem depender de alguém notar a falha.
CREATE TABLE IF NOT EXISTS bronze.controle_execucao (
    id_execucao        BIGSERIAL PRIMARY KEY,
    tipo_carga         VARCHAR(30) NOT NULL,
    data_inicio_janela DATE NOT NULL,
    data_fim_janela    DATE NOT NULL,
    qtd_proposicoes    INT,
    executado_em       TIMESTAMP NOT NULL DEFAULT now()
);
