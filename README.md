# Monitoramento de Proposições Legislativas — Suinocultura

Pipeline de dados que automatiza o acompanhamento de proposições legislativas relevantes para a suinocultura, extraindo e organizando informações da API de Dados Abertos da Câmara dos Deputados.

![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-14+-4169E1?logo=postgresql&logoColor=white)
![Status](https://img.shields.io/badge/status-em%20desenvolvimento-yellow)

---

## Sobre o projeto

O time político da ABCS acompanha manualmente as proposições legislativas que impactam o setor de suinocultura: abre o portal da Câmara, busca por número, lê a ementa, identifica autor e comissão, anota a última movimentação. É um processo repetitivo que consome tempo de profissionais cuja competência é análise política, não coleta de dados.

Este projeto automatiza essa coleta: extrai as proposições relevantes diretamente da API pública da Câmara, armazena o histórico em um banco estruturado e entrega os dados prontos para consumo em dashboard ou planilha — liberando o time para focar em análise e articulação.

## O problema

Sem esse pipeline, cada uma dessas perguntas exige navegação manual repetida:

- Quais proposições relacionadas à suinocultura estão tramitando?
- Quem é o autor, de qual partido e estado?
- Em qual comissão a proposição está agora?
- Quando foi a última movimentação?
- Surgiram proposições novas que ainda não estavam no radar?

Não há histórico consolidado, alertas ou visão comparativa — só o portal, uma proposição de cada vez.

## Como funciona

A extração usa duas camadas de filtro: um filtro amplo por tema legislativo (reduz o universo de ~27.000 proposições para as classificadas em Agricultura/Pecuária e Meio Ambiente), e um filtro fino por palavra-chave mantido como configuração — novos termos podem ser adicionados sem reprocessar a extração.

O filtro fino roda contra a ementa **e** contra o campo de indexação temática que a própria Câmara mantém por proposição — a ementa sozinha se mostrou insuficiente (ex.: uma proposição sobre bem-estar de suínos pode ter ementa genérica como "Institui o Código Federal de Bem-Estar Animal", sem citar o termo, mas a Câmara já indexa isso). O matching usa regex ancorada por início de palavra em vez de busca por substring simples, para cobrir variações de gênero/número (suíno/suína/suínos) sem gerar falso positivo por coincidência textual (ex.: um radical mal ancorado para "aves" bateria em "grave"; para "ração" bateria em "tração").

Os dados passam por três camadas, seguindo o padrão medallion:

```
API Câmara dos Deputados
        │
        ▼
 Scripts Python (extração e carga)
        │
        ▼
   PostgreSQL
    ├── bronze  → JSON bruto da API, append-only (auditoria e reprocessamento)
    ├── silver  → dados normalizados em tabelas relacionais
    └── gold    → views analíticas prontas para consumo (keywords aplicadas aqui)
        │
        ▼
  Power BI / planilha exportada
```

A infraestrutura é local (sem dependência de nuvem): o volume de dados é pequeno, o consumidor é um time interno, e a decisão prioriza iteração rápida sobre complexidade operacional. Uma eventual migração para infraestrutura compartilhada não exige alterar a lógica de negócio, apenas o destino da conexão.

## Stack

| Camada | Tecnologia |
|---|---|
| Extração e transformação | Python (`requests`, `pandas`) |
| Armazenamento | PostgreSQL |
| Orquestração local | Task Scheduler / cron |
| Visualização | Power BI Desktop ou export CSV |

## Fonte de dados

[API de Dados Abertos da Câmara dos Deputados](https://dadosabertos.camara.leg.br/swagger/api.html) — pública, gratuita, mantida pela própria Câmara. O pipeline consome os endpoints de listagem, detalhes, autores, temas e tramitações de cada proposição.

## Status do projeto

- [x] Extração e carga da camada **bronze** (proposições, autores, temas e tramitações) — ~1.530 proposições únicas
- [x] Modelagem da camada **silver** (normalização relacional + tabelas de referência)
- [x] Views analíticas da camada **gold** com matching de palavras-chave — ~280 proposições relevantes identificadas
- [ ] Dashboard Power BI
- [ ] Carga incremental diária automatizada

**Próximas fases:** enriquecimento de autores com partido/UF (via endpoint `/deputados`), pautas de comissões e votações, alertas automáticos, e dados do Senado Federal.

## Rodando localmente

```bash
git clone <url-do-repositorio>
cd monitoramento_proposicoes

python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt

# copie src/.env.example para src/.env e preencha as credenciais do seu Postgres
cp src/.env.example src/.env

cd src
python setup_db.py             # cria os schemas e tabelas
python extract_bronze.py       # roda a carga histórica (bronze)
python load_dimensoes.py       # popula tabelas de referência (temas e keywords)
python load_silver.py          # transforma bronze em tabelas relacionais (silver)
```

## Autor

**Erick Silva** — Analista de BI, ABCS
