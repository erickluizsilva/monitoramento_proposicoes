CREATE SCHEMA IF NOT EXISTS gold;

-- Keywords são aplicadas exclusivamente aqui na gold (nunca na silver),
-- para permitir adicionar termos sem reprocessar a extração.
-- dim_keyword.termo é um fragmento de regex ancorado por palavra (ver keywords.py) —
-- por isso o match usa ~* (regex case-insensitive), não ILIKE. O match considera
-- tanto a ementa quanto o campo de indexação curado pela própria Câmara
-- (keywords_camara), que às vezes cita o assunto mesmo quando a ementa não o faz.
CREATE OR REPLACE VIEW gold.vw_proposicao_keywords AS
SELECT
    p.id_proposicao,
    string_agg(DISTINCT k.rotulo, ', ' ORDER BY k.rotulo) AS keywords_encontradas
FROM silver.proposicao p
JOIN silver.dim_keyword k
    ON k.ativo
    AND (p.ementa ~* k.termo OR p.keywords_camara ~* k.termo)
GROUP BY p.id_proposicao;

-- View principal: uma linha por proposição relevante (com pelo menos 1 keyword).
-- partido/UF do autor principal são os ATUAIS (via silver.dim_deputado), não os da
-- data de apresentação da proposição — só se aplica quando o autor é deputado.
CREATE OR REPLACE VIEW gold.vw_monitoramento AS
SELECT
    p.id_proposicao,
    p.sigla_tipo || ' ' || p.numero || '/' || p.ano AS identificacao,
    p.ementa,
    autor.nome AS autor_principal,
    autor.tipo AS tipo_autor_principal,
    dep.sigla_partido AS partido_autor_principal,
    dep.sigla_uf AS uf_autor_principal,
    p.descricao_situacao AS situacao_atual,
    p.sigla_orgao_atual AS orgao_atual,
    COALESCE(p.descricao_tramitacao, p.despacho) AS ultima_movimentacao,
    p.data_ultima_movimentacao,
    (CURRENT_DATE - p.data_ultima_movimentacao::date) AS dias_sem_movimentacao,
    kw.keywords_encontradas,
    p.link_direto
FROM silver.proposicao p
JOIN gold.vw_proposicao_keywords kw ON kw.id_proposicao = p.id_proposicao
LEFT JOIN silver.proposicoes_proponentes autor
    ON autor.id_proposicao = p.id_proposicao AND autor.ordem_assinatura = 1
LEFT JOIN silver.dim_deputado dep
    ON autor.tipo = 'Deputado(a)'
    AND dep.id_deputado = (regexp_replace(autor.uri, '.*/', ''))::int
ORDER BY p.data_ultima_movimentacao DESC;

-- Histórico completo de tramitações, para drill-down a partir da view principal.
CREATE OR REPLACE VIEW gold.vw_tramitacoes AS
SELECT
    t.id_proposicao,
    p.sigla_tipo || ' ' || p.numero || '/' || p.ano AS identificacao,
    t.sequencia,
    t.data_hora,
    t.sigla_orgao,
    t.descricao_situacao,
    t.descricao_tramitacao,
    t.despacho
FROM silver.tramitacao t
JOIN silver.proposicao p ON p.id_proposicao = t.id_proposicao
ORDER BY t.id_proposicao, t.sequencia;

-- Auditoria: proposições do tema 64 (Agricultura, Pecuária, Pesca e Extrativismo)
-- que não bateram em nenhuma keyword ativa — usada para descobrir termos faltantes.
CREATE OR REPLACE VIEW gold.vw_proposicoes_sem_keyword AS
SELECT
    p.id_proposicao,
    p.sigla_tipo || ' ' || p.numero || '/' || p.ano AS identificacao,
    p.ementa,
    p.link_direto
FROM silver.proposicao p
JOIN silver.proposicao_tema pt
    ON pt.id_proposicao = p.id_proposicao AND pt.cod_tema = 64
WHERE NOT EXISTS (
    SELECT 1 FROM gold.vw_proposicao_keywords kw WHERE kw.id_proposicao = p.id_proposicao
);
