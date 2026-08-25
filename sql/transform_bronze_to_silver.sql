-- Transformação bronze -> silver via jsonb_array_elements/extração de campos.
-- proposicao, proposicoes_proponentes e proposicao_tema refletem o estado mais
-- recente (última linha de bronze por id_proposicao) e usam upsert.
-- tramitacao é histórica: acumula de todas as linhas de bronze, nunca sobrescreve
-- uma sequência já vista (idempotente entre execuções).

-- 1) silver.proposicao (depende de nada; demais tabelas têm FK para ela)
WITH ultimo_bronze AS (
    SELECT DISTINCT ON (id_proposicao) id_proposicao, payload, data_extracao
    FROM bronze.proposicoes_json
    ORDER BY id_proposicao, data_extracao DESC
)
INSERT INTO silver.proposicao (
    id_proposicao, sigla_tipo, descricao_tipo, numero, ano, ementa,
    data_apresentacao, sigla_orgao_atual, id_orgao_atual, descricao_situacao, descricao_tramitacao,
    despacho, data_ultima_movimentacao, cod_situacao, link_direto, keywords_camara, data_extracao
)
SELECT
    b.id_proposicao,
    b.payload->>'siglaTipo',
    b.payload->>'descricaoTipo',
    (b.payload->>'numero')::int,
    (b.payload->>'ano')::int,
    b.payload->>'ementa',
    (b.payload->>'dataApresentacao')::timestamp,
    b.payload#>>'{statusProposicao,siglaOrgao}',
    (regexp_replace(b.payload#>>'{statusProposicao,uriOrgao}', '.*/', ''))::int,
    b.payload#>>'{statusProposicao,descricaoSituacao}',
    b.payload#>>'{statusProposicao,descricaoTramitacao}',
    b.payload#>>'{statusProposicao,despacho}',
    (b.payload#>>'{statusProposicao,dataHora}')::timestamp,
    (b.payload#>>'{statusProposicao,codSituacao}')::int,
    'https://www.camara.leg.br/proposicoesWeb/fichadetramitacao?idProposicao=' || b.id_proposicao,
    b.payload->>'keywords',
    b.data_extracao
FROM ultimo_bronze b
ON CONFLICT (id_proposicao) DO UPDATE SET
    sigla_tipo = EXCLUDED.sigla_tipo,
    descricao_tipo = EXCLUDED.descricao_tipo,
    numero = EXCLUDED.numero,
    ano = EXCLUDED.ano,
    ementa = EXCLUDED.ementa,
    data_apresentacao = EXCLUDED.data_apresentacao,
    sigla_orgao_atual = EXCLUDED.sigla_orgao_atual,
    id_orgao_atual = EXCLUDED.id_orgao_atual,
    descricao_situacao = EXCLUDED.descricao_situacao,
    descricao_tramitacao = EXCLUDED.descricao_tramitacao,
    despacho = EXCLUDED.despacho,
    keywords_camara = EXCLUDED.keywords_camara,
    data_ultima_movimentacao = EXCLUDED.data_ultima_movimentacao,
    cod_situacao = EXCLUDED.cod_situacao,
    link_direto = EXCLUDED.link_direto,
    data_extracao = EXCLUDED.data_extracao;

-- 2) silver.proposicoes_proponentes
WITH ultimo_bronze AS (
    SELECT DISTINCT ON (id_proposicao) id_proposicao, payload, data_extracao
    FROM bronze.autores_json
    ORDER BY id_proposicao, data_extracao DESC
)
INSERT INTO silver.proposicoes_proponentes (
    id_proposicao, ordem_assinatura, uri, nome, tipo, cod_tipo, proponente, data_extracao
)
SELECT
    b.id_proposicao,
    (elem->>'ordemAssinatura')::int,
    elem->>'uri',
    elem->>'nome',
    elem->>'tipo',
    (elem->>'codTipo')::int,
    (elem->>'proponente')::int,
    b.data_extracao
FROM ultimo_bronze b, jsonb_array_elements(b.payload) elem
ON CONFLICT (id_proposicao, ordem_assinatura) DO UPDATE SET
    uri = EXCLUDED.uri,
    nome = EXCLUDED.nome,
    tipo = EXCLUDED.tipo,
    cod_tipo = EXCLUDED.cod_tipo,
    proponente = EXCLUDED.proponente,
    data_extracao = EXCLUDED.data_extracao;

-- 3) silver.proposicao_tema
WITH ultimo_bronze AS (
    SELECT DISTINCT ON (id_proposicao) id_proposicao, payload, data_extracao
    FROM bronze.temas_json
    ORDER BY id_proposicao, data_extracao DESC
)
INSERT INTO silver.proposicao_tema (id_proposicao, cod_tema, tema, relevancia, data_extracao)
SELECT
    b.id_proposicao,
    (elem->>'codTema')::int,
    elem->>'tema',
    (elem->>'relevancia')::int,
    b.data_extracao
FROM ultimo_bronze b, jsonb_array_elements(b.payload) elem
ON CONFLICT (id_proposicao, cod_tema) DO UPDATE SET
    tema = EXCLUDED.tema,
    relevancia = EXCLUDED.relevancia,
    data_extracao = EXCLUDED.data_extracao;

-- 4) silver.tramitacao (histórica: acumula de todas as linhas de bronze já vistas)
INSERT INTO silver.tramitacao (
    id_proposicao, sequencia, data_hora, sigla_orgao, uri_orgao, id_orgao, cod_situacao,
    descricao_situacao, descricao_tramitacao, despacho, url, cod_tipo_tramitacao, data_extracao
)
SELECT
    b.id_proposicao,
    (elem->>'sequencia')::int,
    (elem->>'dataHora')::timestamp,
    elem->>'siglaOrgao',
    elem->>'uriOrgao',
    (regexp_replace(elem->>'uriOrgao', '.*/', ''))::int,
    (elem->>'codSituacao')::int,
    elem->>'descricaoSituacao',
    elem->>'descricaoTramitacao',
    elem->>'despacho',
    elem->>'url',
    elem->>'codTipoTramitacao',
    b.data_extracao
FROM bronze.tramitacoes_json b, jsonb_array_elements(b.payload) elem
ON CONFLICT (id_proposicao, sequencia) DO NOTHING;

-- 5) silver.evento (o item de listagem já tem tudo; sem chamada a /eventos/{id})
WITH ultimo_bronze AS (
    SELECT DISTINCT ON (id_evento) id_evento, payload, data_extracao
    FROM bronze.eventos_json
    ORDER BY id_evento, data_extracao DESC
)
INSERT INTO silver.evento (
    id_evento, data_hora_inicio, data_hora_fim, descricao_tipo, situacao, descricao,
    id_orgao, sigla_orgao, nome_orgao, local_nome, url_registro, data_extracao
)
SELECT
    b.id_evento,
    (b.payload->>'dataHoraInicio')::timestamp,
    (b.payload->>'dataHoraFim')::timestamp,
    b.payload->>'descricaoTipo',
    b.payload->>'situacao',
    b.payload->>'descricao',
    (b.payload#>>'{orgaos,0,id}')::int,
    b.payload#>>'{orgaos,0,sigla}',
    b.payload#>>'{orgaos,0,nome}',
    b.payload#>>'{localCamara,nome}',
    b.payload->>'urlRegistro',
    b.data_extracao
FROM ultimo_bronze b
ON CONFLICT (id_evento) DO UPDATE SET
    data_hora_inicio = EXCLUDED.data_hora_inicio,
    data_hora_fim = EXCLUDED.data_hora_fim,
    descricao_tipo = EXCLUDED.descricao_tipo,
    situacao = EXCLUDED.situacao,
    descricao = EXCLUDED.descricao,
    id_orgao = EXCLUDED.id_orgao,
    sigla_orgao = EXCLUDED.sigla_orgao,
    nome_orgao = EXCLUDED.nome_orgao,
    local_nome = EXCLUDED.local_nome,
    url_registro = EXCLUDED.url_registro,
    data_extracao = EXCLUDED.data_extracao;

-- 6) silver.evento_pauta: sem chave natural confiável dentro do evento (ver
-- schema_silver.sql), então substitui a pauta inteira de cada evento presente
-- neste lote de bronze, a partir do snapshot mais recente. 'id' de
-- proposicao_/proposicaoRelacionada_/relator vêm como número ou string
-- dependendo do item na API — #>>'{...}' sempre retorna texto, então o cast
-- funciona nos dois casos.
DELETE FROM silver.evento_pauta
WHERE id_evento IN (SELECT DISTINCT id_evento FROM bronze.eventos_pauta_json);

WITH ultimo_bronze AS (
    SELECT DISTINCT ON (id_evento) id_evento, payload, data_extracao
    FROM bronze.eventos_pauta_json
    ORDER BY id_evento, data_extracao DESC
)
INSERT INTO silver.evento_pauta (
    id_evento, ordem, topico, regime, titulo, id_proposicao, id_proposicao_relacionada,
    id_deputado_relator, nome_relator, uri_votacao, situacao_item, data_extracao
)
SELECT
    b.id_evento,
    (elem->>'ordem')::int,
    elem->>'topico',
    elem->>'regime',
    elem->>'titulo',
    (elem#>>'{proposicao_,id}')::bigint,
    (elem#>>'{proposicaoRelacionada_,id}')::bigint,
    (regexp_replace(elem#>>'{relator,uri}', '.*/', ''))::int,
    elem#>>'{relator,nome}',
    elem->>'uriVotacao',
    elem->>'situacaoItem',
    b.data_extracao
FROM ultimo_bronze b, jsonb_array_elements(b.payload) elem;
