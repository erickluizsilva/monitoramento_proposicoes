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
