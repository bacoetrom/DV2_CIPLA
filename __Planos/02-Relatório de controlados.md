# MIT041 – Plano Técnico: Relatório de Balanço de Estoque de Reagentes Controlados

08/10/2026

## 1. Contexto e objetivo

O relatório será construído a partir do padrão **MATR445**, reaproveitando a configuração de produtos controlados que a TOTVS já prevê na **SB5**. Com isso, restam apenas 2 a 5 campos realmente customizados.

| Item | Valor |
| --- | --- |
| Cliente | 720 DEGREES CONSULTORIA LTDA (TFEQTE00) |
| Projeto | FÊNIX (D0000826540001) – proposta AAQGKV |
| Módulo | Estoque/Custos (SIGAEST) |
| Especificação funcional | Especificação da Customização v1.0 de 26/08/2026 (Pabo Regis), que remete a esta MIT041 técnica |
| Criticidade | Alto impacto (não implementável sem modificação) |
| Execução | Sob demanda |

**Objetivo:** emitir, por filial, produto e lote, o balanço do período (saldo inicial, compras, consumo, perdas/transferências e saldo final) junto com as informações regulatórias do reagente (órgão, nº CAS, FDS, limite de estoque). O relatório tem cabeçalho bilíngue (PT/EN) e exporta para Excel e PDF.

**Fora do escopo** (conforme a especificação): fechamento de estoque, inventário, transferências como processo, e substituição das declarações oficiais aos órgãos.

## 2. Análise dos fontes padrão do pacote

Nenhum relatório padrão do pacote entrega sozinho o balanço do período por lote. O MATR445 é o mais aderente; MATR330, MATR425 e MATR435 fornecem trechos de lógica.

O pacote `26-08-17-FONTE_RELATORIO_CUSTOMIZADOS_BACKOFFICE` contém:

| Pasta | Conteúdo |
| --- | --- |
| `convertido/` | 335 fontes `*_CUSTOM.PRW/PRX` (relatórios padrão convertidos em `U_xxxxC`) e 990 arquivos `.tres` (pt-br, en, es) |
| `ch-tres-output/` | 334 `.CH` que mapeiam `STR00xx` para `FWI18NLang` |
| `individuais/`, `full/` | Patches `.PTM` compilados |

Dos 85 MATR de Compras/Estoque, foram avaliados os que leem saldo (SB2/SB9/SB8) e movimentos (SD1/SD2/SD3/SD5):

| Fonte | Título | Aderência | Avaliação |
| --- | --- | --- | --- |
| MATR445 | Análise da Movimentação | Alta – base | Período, produto e armazém; query única `UNION` SB1/SD1/SD2/SD3; saldo inicial via `CalcEst()`; opção "lista sem movimento"; 514 linhas |
| MATR330 | Mapa das Movimentações | Alta – lógica | Já tem Saldo Ini / Compras / Requisições / Transferências / Saldo Fim e a regra por `D3_CF` e CFOP; porém financeiro, agrupado por tipo/grupo, 1.462 linhas |
| MATR425 | Posição por Lote/Sub-Lote | Alta – lógica | Query SB8 com filtro `B8_DTVALID` de/até; imprime `B8_DATA` e `B8_DTVALID` |
| MATR435 | Kardex por Lote/Sub-Lote | Média – lógica | `CalcEstL()` para saldo por lote numa data; classificação por `D5_ORIGLAN`; usa `IndRegua` em SD5 (legado, lento) |
| MATR320 | Resumo das Entradas e Saídas | Baixa | Agrupa só por tipo de material |
| MATR900 / 910 / 902 / 420 | Kardex físico (sequência, dia, FIFO, resumo diário) | Baixa | Lista movimento a movimento, sem balanço consolidado |
| MATR240 / 260 / 390 | Saldos / Posição / Diferenças | Baixa | Posição atual, sem período |
| MATR230 / 300 | Requisições / Movimentações internas | Baixa | Apenas SD3 |

Os relatórios padrão de controlados (MATR913, MATR947, MATR949, MATR462 e a rotina MATA950) **não estão no pacote**; existem apenas no RPO padrão.

## 3. Fonte base e trechos reaproveitados

O esqueleto vem do MATR445. A granularidade passa de produto para **Filial + Produto + Lote + Armazém**, porque o layout exige lote, fabricação e validade.

| Origem | O que se reaproveita | Arquivo no pacote |
| --- | --- | --- |
| MATR445 | Estrutura `ReportDef` / `ReportPrint`, `BeginSql` com `UNION`, laço por produto, parâmetro "lista sem movimento", validação de período máximo (`U_MR445DTC`, 4.095 dias) | `convertido/matr445_CUSTOM.prx` |
| MATR425 | Query na SB8 com filtro de validade (`B8_DTVALID` de/até) e colunas `B8_DATA`, `B8_DTVALID` | `convertido/matr425_CUSTOM.prx` |
| MATR435 | `CalcEstL(cProd, cLocal, dData, cLote, cSubLote)` para saldo inicial e final por lote; tratamento de sublote (`Rastro(cProd,"S")`) | `convertido/matr435_CUSTOM.prx` |
| MATR330 | Classificação dos movimentos por `D3_CF`, CFOP e `D1_TIPO`; ponto de entrada `R330TRANS` como referência | `convertido/matr330_CUSTOM.prx` |

**Não reaproveitar:** o `IndRegua` sobre SD5 do MATR435. Os movimentos por lote serão lidos por query SQL na SD5 com join em SD1/SD2/SD3 por `D5_NUMSEQ`.

Produto controlado **sem rastro de lote** usa `CalcEst()`, como no MATR445, e sai com as colunas de lote vazias.

## 4. Padrão TOTVS para produtos controlados

O Protheus já identifica produtos controlados por órgão através de flags na SB5. O nome de cada flag é apontado por um parâmetro `MV_`. O relatório customizado deve ler esses mesmos parâmetros.

| Órgão | Rotina padrão | Flag na SB5 (nome sugerido) | Parâmetro | Observações |
| --- | --- | --- | --- | --- |
| Polícia Federal (SIPROQUIM 2) | MATA950 (arquivo) + MATR913 (conferência) | `B5_PRODPF` (S/N) | `MV_PRODPF` | Exige `MAPAS.INI` no StartPath e grupos `MAPASV2` e `MTR913V2` |
| Exército (Comando Militar) | MATR949 – Mapa Demonstrativo de Entradas e Saídas | `B5_PRODEX` (S/N) | `MV_MTR949A` | `MV_MTR949B/C`: país de origem em SA1/SA2; `MV_MTR949D`: descrição (ex.: `B5_DESC`) |
| Polícia Civil SP | MATR947 – Mapa de Produtos Controlados (menu SIGAFIS) | `B5_PRODCON` (S/N) | `MV_MTR947A` | `MV_TRANSF1`: transportadora na SF1; exige fechamento de estoque |
| Civil + Exército (legado) | MATR462 – Produtos Controlados | – | – | Emissão do mapa civil de compra e venda e do mapa do Exército |

As flags `B5_PRODPF`, `B5_PRODEX` e `B5_PRODCON` **não vêm no dicionário padrão**. O TDN orienta criá-las com esses nomes sugeridos. São configuração documentada, não customização do projeto.

**Configuração complementar da Polícia Federal (TDN):**

| Campo sugerido | Uso | Parâmetro |
| --- | --- | --- |
| `B5_CODMAPA` (C 11) | Código do produto no SIPROQUIM 2 (ex.: TPN12951074) | `MV_CODMAPA` |
| `B5_DESCPR` (C 70) | Nome comercial; sem ele, o padrão usa `B1_DESC` | `MV_DESCPR` |
| `B5_UNMAPA`, `B5_CONVMAP`, `B5_TCONVMA` | Conversão da UM para KG ou L | `MV_CPOMAPA` |
| `B5_PFCOMPO` | Produto ou resíduo composto | `MV_PFCOMPO` |
| `B5_MAPVII` | Produto da lista VII da Portaria 240/2019 | `MV_MAPIV` |
| `F5_DESPROD` | Descrição de produção/consumo no tipo de movimento | `MV_DESCPRO` |
| – (usa `B1_GRUPO`) | Identificação de resíduo controlado | `MV_GRUPRES` |
| – | CFOPs de armazenagem (seção AR) | `MV_CFOPAR` |

**Campos SB5 nativos usados pelos mapas:** `B5_CEME` (nome científico), `B5_ESTMAT` (estado físico S/L/G), `B5_CONCENT` (concentração), `B5_DENSID` (densidade), `B5_ONU` + `B5_ITEM` (nº ONU).

## 5. Mapeamento campo a campo

Das 18 informações mapeadas, 13 já têm origem padrão ou de configuração padrão. Só o nº CAS e a FDS são customizados com certeza; outras 3 dependem de validação com o cliente.

| Coluna da especificação (PT / EN) | Origem | Situação |
| --- | --- | --- |
| Código / Code | `B1_COD` | Padrão |
| Nome comercial / Trade name | `B5_DESCPR` via `MV_DESCPR`; senão `B1_DESC` | Config. PF |
| Nome químico / Chemical name | `B5_CEME` (Nome Científico) | Padrão nativo |
| Forma / Physical form | `B5_ESTMAT` (S=Sólido, L=Líquido, G=Gasoso) | Padrão nativo |
| Órgão fiscalizador / Regulatory agency | Derivado das flags `MV_PRODPF`, `MV_MTR949A`, `MV_MTR947A` (pode haver mais de um) | Config. padrão |
| Controlado / Controlled | Pelo menos uma flag = S | Config. padrão |
| Lote / Batch | `B8_LOTECTL` (+ `B8_NUMLOTE` se sublote) | Padrão |
| Lote do fabricante / Manufacturer batch | `B8_LOTEFOR` (Num. Lote no Fornecedor) | Padrão |
| Fabricante / Manufacturer | SA5 – Amarração Produto x Fornecedor: `A5_FABR` + `A5_FALOJA` → `SA2.A2_NOME`, localizada pelo fornecedor do lote (`B8_CLIFOR` + `B8_LOJA`) e produto; regra abaixo | Padrão |
| Data de fabricação / Manufacturing date | `B8_DFABRIC` | Padrão |
| Data de validade / Expiry date | `B8_DTVALID` | Padrão |
| Dados da NF de compra / Purchase invoice | `B8_DOC`, `B8_SERIE`, `B8_ITEM`, `B8_CLIFOR`, `B8_LOJA` → SF1/SD1 | Padrão |
| Código SIPROQUIM, concentração, densidade, nº ONU (opcionais) | `B5_CODMAPA`, `B5_CONCENT`, `B5_DENSID`, `B5_ONU` | Padrão / config. PF |
| Nº CAS / CAS number | `B5_XCAS` | Customizado |
| FDS / SDS | `B5_XFDS` (nº/revisão ou link) | Customizado |
| Armazenamento / Storage | `B5_XARMAZ`; `B5_CODZON` é zona de WMS e não atende | A validar |
| Limite de estoque / Stock limit | Avaliar `B1_EMAX`; se variar por órgão ou licença, `B5_XLIMEST` | A validar |
| Responsável, Conferente, Observações | Colunas em branco para assinatura (proposta) | A validar |

**Regra do fabricante (SA5 + SB8):**

A SA5 registra quem fabrica cada produto por fornecedor (`A5_FABR`/`A5_FALOJA`, consulta SA2) e se o fornecedor é Fabricante, Revendedor ou Permuta (`A5_FABREV` = F/R/P). Isso elimina a premissa "fornecedor = fabricante" e trata compras via distribuidor.

1. Identificar o fornecedor do lote pela origem (`B8_ORIGLAN`):
    - `CP` (compras): `B8_CLIFOR`/`B8_LOJA`.
    - `TR` (transferência): o lote nasceu em outra filial ou armazém; usar o `B8_CLIFOR`/`B8_LOJA` do lote de origem (mesmo produto e `B8_LOTECTL`, com `B8_ORIGLAN = 'CP'`).
    - `PR` (produção): fabricante = a própria empresa (`SM0`); encerra aqui.
2. Buscar a SA5 pelo índice 1 (`A5_FILIAL + A5_FORNECE + A5_LOJA + A5_PRODUTO`).
3. `A5_FABR` preenchido: fabricante = `SA2` de `A5_FABR + A5_FALOJA`.
4. `A5_FABR` vazio e `A5_FABREV = 'F'` (ou vazio): fabricante = o próprio fornecedor.
5. `A5_FABREV = 'R'` ou `'P'` sem `A5_FABR`: imprimir o fornecedor com a marca "revendedor – fabricante não informado" e listar no log de cadastro incompleto.
6. Mais de uma SA5 para o mesmo fornecedor e produto com fabricantes diferentes: usar a amarração cujo `A5_CODPRF` (código do produto no fornecedor) consta na NF de entrada, se houver; senão, sinalizar ambiguidade.

Join exato com a NF de entrada: `D1_DOC = B8_DOC`, `D1_SERIE = B8_SERIE`, `D1_FORNECE = B8_CLIFOR`, `D1_LOJA = B8_LOJA`, `D1_COD = B8_PRODUTO`, `D1_ITEM = B8_ITEM`.

Os campos customizados ficam na **SB5**, junto dos demais regulatórios, e não na SB1.

## 6. Regras de cálculo do balanço

Cada linha é Filial + Produto + Lote + Armazém. O saldo final calculado tem que bater com o saldo do sistema na data final; se divergir, a linha é sinalizada.

```
Saldo Final = Saldo Inicial + Compras - Consumo - Perdas/Transferências
```

| Coluna | Fonte e regra | Base no padrão |
| --- | --- | --- |
| Saldo inicial | `CalcEstL(cProd, cLocal, dDataIni, cLote, cSubLote)[1]`; sem rastro, `CalcEst(cProd, cLocal, dDataIni)[1]` | MATR435 / MATR445 |
| Compras | SD1 com TES que movimenta estoque (`F4_ESTOQUE='S'`) e `D1_TIPO` normal, `D1_ORIGLAN <> 'LF'`; exclui CFOP 1151/1152/2151/2152/1552/2552; devolução de compra (SD2 `D2_TIPO='D'`) abate | MATR330 |
| Consumo | SD3 `D3_CF` RE0/DE0, RE1/DE1, RE5/DE5, RE6/DE6, REA/DEA (requisição menos devolução) + SD2 de vendas; `D3_ESTORNO <> 'S'` | MATR330 |
| Perdas/Transferências | **Pendente com o cliente.** Proposta: SD3 RE4/DE4 e RE7/DE7 (transferência entre armazéns), SD1/SD2 CFOP 5151/5152/6151/6152 (entre filiais) e TMs de perda/ajuste de inventário informados pelo cliente | MATR330 |
| Saldo final | Fórmula acima, conferida com `CalcEstL(..., dDataFim + 1, ...)` | MATR435 |

**Leitura por lote:** os movimentos vêm da SD5 (`D5_PRODUTO`, `D5_LOCAL`, `D5_LOTECTL`, `D5_NUMLOTE`, `D5_DATA`), com join em SD1/SD2/SD3 por `D5_NUMSEQ` para obter `CF`, TM, TES e CFOP. `D5_ESTORNO = 'S'` é ignorado.

**Unidade:** opcionalmente, converter para KG ou L conforme `MV_CPOMAPA`, para bater com o que vai ao SIPROQUIM.

**Reagente sem movimento no período:** imprime saldo inicial = saldo final, com as colunas de movimento zeradas.

## 7. Dicionário de dados

Nenhum parâmetro SX6 novo é necessário, como pede a especificação. Os parâmetros abaixo são os da configuração padrão dos mapas, criados apenas se o cliente ainda não os tiver.

**7.1 Campos de configuração padrão (criar se não existirem)**

| Tabela | Campo | Tipo / Tam. | Título | Opções | Parâmetro |
| --- | --- | --- | --- | --- | --- |
| SB5 | `B5_PRODPF` | C 1 | Prod.Cont.PF | S=Sim;N=Não | `MV_PRODPF` |
| SB5 | `B5_PRODEX` | C 1 | Prod.Cont.Ex | S=Sim;N=Não | `MV_MTR949A` |
| SB5 | `B5_PRODCON` | C 1 | Prod. Control. | S=Sim;N=Não | `MV_MTR947A` |
| SB5 | `B5_CODMAPA` | C 11 | Cód.MAPAS | – | `MV_CODMAPA` |
| SB5 | `B5_DESCPR` | C 70 | Nome Comerc. | – | `MV_DESCPR` |

**7.2 Campos customizados do projeto**

| Tabela | Campo | Tipo / Tam. | Título | Situação |
| --- | --- | --- | --- | --- |
| SB5 | `B5_XCAS` | C 12 | Nº CAS | Confirmado |
| SB5 | `B5_XFDS` | C 100 | FDS (nº/rev. ou link) | Confirmado |
| SB5 | `B5_XANVISA` | C 1 (S=Sim;N=Não) | Prod.Cont.ANVISA | Confirmado pelo protótipo (opção ANVISA); nome a validar (P7) |
| SB5 | `B5_XARMAZ` | C 60 | Cond. Armazen. | A validar |
| SB5 | `B5_XLIMEST` | N 14,2 | Limite Estoque | A validar (alternativa: `B1_EMAX`) |

O campo de fabricante foi descartado: o fabricante vem da amarração Produto x Fornecedor (SA5: `A5_FABR`, `A5_FALOJA`, `A5_FABREV`), localizada pelo fornecedor do lote na SB8. O lote do fabricante vem de `B8_LOTEFOR`.

**7.3 Grupo de perguntas (SX1) `XESTR041`**

| Ordem | Pergunta (conforme protótipo) | Tipo / Tam. | Consulta | Obrigatória |
| --- | --- | --- | --- | --- |
| 01 / 02 | Filial de / Filial até | C (tam. filial) | SM0 | Sim |
| 03 / 04 | Período de / Período até | D 8 | – | Sim |
| 05 / 06 | Grupo de Produto de / até | C (tam. `BM_GRUPO`) | SBM | Sim |
| 07 / 08 | Produto/Reagente de / até | C (tam. `B1_COD`) | SB1 | Sim |
| 09 / 10 | Validade de / Validade até | D 8 | – | Sim |
| 11 | Quais Órgãos Fiscalizadores? | C 10 (até 5 códigos de 2 posições) | Seleção múltipla via `f_Opcoes` (tela "Escolha Padrões") | Sim |

O filtro "Controlado" da especificação fica dentro da pergunta 11: a opção "NÃO CONTROLADO" só entra quando o usuário a marca (pendência P3 resolvida).

**Opções da pergunta 11 (Órgãos Fiscalizadores)**

| Item | Código | Descrição | Regra aplicada na SB5 |
| --- | --- | --- | --- |
| 00001 | PC | POLÍCIA CIVIL | Campo de `MV_MTR947A` = 'S' |
| 00002 | PF | POLÍCIA FEDERAL | Campo de `MV_PRODPF` = 'S' |
| 00003 | EX | EXÉRCITO | Campo de `MV_MTR949A` = 'S' |
| 00004 | AV | ANVISA | Campo `B5_XANVISA` = 'S' (não há flag padrão de ANVISA no SIGAEST; pendência P7) |
| 00005 | NC | NÃO CONTROLADO | Nenhuma das flags acima = 'S' |

Exemplo do protótipo: Polícia Federal + Exército marcados → conteúdo `PFEX` → `WHERE (B5_PRODPF = 'S' OR B5_PRODEX = 'S')`.

Implementação: `X1_VALID` da pergunta 11 chama `U_ER041ORG()`, que monta o array de opções e abre `f_Opcoes(@cRet, "Escolha Padrões", aOpcoes, cOpcoes, , , .F., 2, 5)` (chave de 2 posições, até 5 elementos). O retorno gravado em `MV_PAR11` é a concatenação dos códigos marcados.

**7.4 Processo dos filtros**

Os filtros são validados em duas camadas: cada pergunta tem `X1_VALID` próprio e, na confirmação da impressão, uma validação geral repete as regras. Assim, nada passa mesmo se o usuário não abrir a tela de parâmetros. Filtro inválido bloqueia a geração com `Help` nomeando o filtro (fluxo A1).

| Filtro | Obrigatório | Validação | Como é aplicado |
| --- | --- | --- | --- |
| Filial de / até | Sim | "Até" preenchido e ≥ "de"; ao menos uma filial existente no intervalo | Laço em `FWLoadSM0()` só nas filiais do intervalo a que o usuário tem acesso; `cFilAnt` trocado a cada filial |
| Período de / até | Sim | Datas preenchidas; "de" ≤ "até"; intervalo ≤ 4.095 dias (`U_MR445DTC`) | Saldo inicial em "Período de"; movimentos com `D5_DATA` no intervalo; saldo final em "Período até" + 1 |
| Grupo de Produto de / até | Sim | "Até" preenchido (aceita `9999`) e ≥ "de"; consulta F3 na SBM | `B1_GRUPO` no intervalo |
| Produto/Reagente de / até | Sim | "Até" preenchido (aceita `ZZZ...`) e ≥ "de"; consulta F3 na SB1 | `B8_PRODUTO` e `B1_COD` no intervalo |
| Validade de / até | Sim | Datas preenchidas; "de" ≤ "até" | `B8_DTVALID` no intervalo; produto sem rastro de lote não é filtrado por validade |
| Quais Órgãos Fiscalizadores? | Sim | Ao menos um item marcado; cada órgão marcado precisa ter o parâmetro/campo configurado, senão bloqueia com "órgão não configurado" | Condições da tabela de opções acima unidas por `OR` |

Lotes com saldo zero e sem movimento no período não são impressos. Lotes com saldo e sem movimento são impressos com saldo inicial = saldo final (cenário da especificação).

**Filtros da especificação que não viram pergunta:**

- **Controlado:** coberto pela pergunta 11 (opção NC). Sem NC marcado, produto não controlado não aparece, o que atende o cenário de teste 3.
- **Armazém e lote:** não estão no protótipo; todos os armazéns e lotes são considerados.
- **Lista lote sem movimento:** retirado para seguir o protótipo; o comportamento fica fixo, conforme o parágrafo acima.

## 8. Arquitetura do fonte e plano de execução

Novo fonte `ESTR041.PRW` (nome a confirmar no padrão do projeto), função `U_ESTR041()`, em TReport, gerado a partir de cópia do `matr445_CUSTOM.prx`.

**8.1 Fluxo de processamento**

1. `U_ESTR041()` chama `ReportDef()` e `oReport:PrintDialog()`.
2. Na confirmação, valida os filtros obrigatórios; se faltar algum, aborta com `Help` indicando qual (fluxo A1), conforme as regras da seção 7.4.
3. Lê os nomes de campo dos parâmetros (`SuperGetMV`): `MV_PRODPF`, `MV_MTR949A`, `MV_MTR947A`, `MV_DESCPR`, `MV_CODMAPA`, `MV_CPOMAPA`. Monta a condição de órgãos a partir de `MV_PAR11` (ex.: `PFEX`), unindo por `OR` as flags dos códigos marcados; NC = nenhuma flag = 'S'.
4. Percorre as filiais do intervalo com `FWLoadSM0()`, trocando `cFilAnt` a cada uma, porque `CalcEst` e `CalcEstL` usam `xFilial` internamente.
5. Por filial, uma query SB8 + SB1 + SB5 (`LEFT JOIN`) com: condição de órgãos do passo 3, grupo de/até (`B1_GRUPO`), produto de/até, validade de/até; e `LEFT JOIN` em SD1/SF1 pela NF de origem do lote (incluindo `B8_ITEM`) e em SA5 (fornecedor do lote + produto) → SA2 (`A5_FABR` + `A5_FALOJA`) para o fabricante. Lotes com `B8_ORIGLAN = 'TR'` buscam o fabricante no lote de origem (seção 5).
6. Por lote: saldo inicial (`CalcEstL` na data inicial), movimentos do período (query SD5 + SD1/SD2/SD3 por `D5_NUMSEQ`) classificados conforme a seção 6, saldo final calculado e conferido.
7. Imprime a linha. Totaliza por produto e por filial com `TRFunction`.

**8.2 Diretrizes de construção**

- Nomes de campo das flags montados dinamicamente na query (`%Exp:%`), nunca fixos no código.
- Cabeçalho bilíngue no título de cada célula: `"Saldo Inicial" + CRLF + "Opening Balance"`. O mecanismo `.tres` do pacote resolve um idioma por vez e não atende PT e EN simultâneos.
- Exportação: nativa do TReport (Planilha e PDF), sem código adicional.
- Período máximo validado como no `U_MR445DTC`.

**8.3 Fases**

1. **Fase 0 – Validação com o cliente:** fechar as pendências P1 a P6 (seção 9) e verificar no ambiente se `MV_PRODPF`, `MV_MTR949A` e `MV_MTR947A` já estão preenchidos.
2. **Fase 1 – Dicionário:** criar os campos de configuração padrão que faltarem, os campos customizados confirmados e o grupo `XESTR041`; atualizar o dicionário desta MIT041.
3. **Fase 2 – Desenvolvimento:** construir o `ESTR041.PRW` conforme 8.1 e 8.2; compilar e incluir no menu do SIGAEST (Relatórios).
4. **Fase 3 – Testes:** executar o plano da seção 9 em base de homologação com reagentes reais.
5. **Fase 4 – Entrega:** gerar patch, documentar parâmetros e colher o aceite.

## 9. Testes, riscos e pendências

Seis pendências precisam ser fechadas com o cliente antes do desenvolvimento; a P1 (origem de Perdas/Transferências) é bloqueante.

**9.1 Pendências com o cliente**

- [ ] **P1** – Origem de Perdas/Transferências: quais TMs, quais `D3_CF` e se transferência entre filiais entra na coluna.
- [ ] **P2** – Lista final de filtros: resolvido pelo protótipo de parâmetros (11 perguntas, incluindo Grupo de Produto e Validade de/até). Atualizar a especificação funcional.
- [ ] **P3** – Filtro "Controlado": resolvido pelo protótipo: opção "NÃO CONTROLADO" na pergunta de órgãos.
- [ ] **P4** – Responsável, Conferente e Observações: colunas em branco para assinatura ou dados gravados?
- [ ] **P5** – Granularidade: uma linha por lote (proposta) ou por produto.
- [ ] **P6** – Armazenamento e limite de estoque: usar campo padrão (`B1_EMAX`) ou customizado. Fabricante: via SA5; confirmar se a amarração Produto x Fornecedor (MATA061) está preenchida com `A5_FABR` para os reagentes controlados.
- [ ] **P7** – ANVISA: o SIGAEST não tem flag nem mapa padrão para ANVISA. Confirmar a criação de `B5_XANVISA` (ou campo já usado pelo cliente) e quais produtos marcar.

**9.2 Plano de testes**

| # | Cenário | Resultado esperado | Conferência |
| --- | --- | --- | --- |
| 1 | Reagente com compras, consumo e perdas no período | Saldo inicial, movimentos e saldo final corretos | MATR445 / MATR330 no mesmo período |
| 2 | Geração sem filtro obrigatório ou sem órgão marcado | Bloqueio com indicação do filtro pendente | – |
| 3 | Produto não controlado com NC desmarcado | Não aparece | Consulta SB5 |
| 4 | Saldo final | Igual ao cálculo manual e a `CalcEstL` na data final | Kardex por lote (MATR435) |
| 5 | Cabeçalho bilíngue | Todas as colunas em PT e EN | Visual |
| 6 | Exportação Excel e PDF | Mesmos dados da tela | Comparar arquivos |
| 7 | Totais por órgão | Entradas e saídas batem com o mapa oficial | MATR913 (PF), MATR949 (Exército), MATR947 (Pol. Civil) |
| 8 | Reagente sem movimento | Saldo inicial = saldo final, movimentos zerados | – |
| 9 | Várias filiais | Saldos isolados por filial | `CalcEst` por filial |
| 10 | Órgãos PF + EX marcados (`PFEX`) | Lista produtos com qualquer uma das duas flags; produto só de Pol. Civil fica fora | Consulta SB5 |
| 11 | Órgão marcado sem parâmetro configurado | Bloqueio "órgão não configurado" | – |
| 12 | Grupo de produto restrito | Só produtos com `B1_GRUPO` no intervalo | Consulta SB1 |

**9.3 Riscos técnicos**

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| `CalcEstL` duas vezes por lote em períodos longos | Lentidão | Limitar período; filtrar só lotes com saldo ou movimento |
| Fechamento de estoque não executado | Saldo inicial divergente | Premissa: fechamento em dia (o MATR947 exige o mesmo) |
| Flags SB5 não preenchidas | Produto fora do relatório | Carga/saneamento cadastral antes do go-live |
| Produto controlado sem rastro de lote | Colunas de lote, fabricante e validade vazias | Usar `CalcEst` por produto e armazém |
| Sublote (`B1_RASTRO='S'`) | Saldo agregado errado | Passar `B8_NUMLOTE` ao `CalcEstL`, como no MATR435 |
| Amarração SA5 ausente ou sem `A5_FABR` para revendedor | Fabricante não identificado | Regra 4/5 da seção 5 + log de cadastro incompleto; saneamento da SA5 antes do go-live |
| Mais de uma SA5 com fabricantes diferentes para o mesmo fornecedor e produto | Fabricante ambíguo | Desempate por `A5_CODPRF`; senão, sinalizar na linha |
| `B8_LOTEFOR` ou `B8_DFABRIC` não informados na entrada | Colunas vazias | Orientar preenchimento no documento de entrada |

## 10. Referências

- [TDN – Mapas de Controle de Produtos Químicos: Guia de Referência](https://tdn.totvs.com/pages/releaseview.action?pageId=506378261)
- [TDN – Configurações mínimas de ambiente (B5_PRODPF, B5_CODMAPA, MAPASV2)](https://tdn.totvs.com/pages/viewpage.action?pageId=506790632)
- [TDN – Configuração do Nome Comercial (B5_DESCPR)](https://tdn.totvs.com/pages/viewpage.action?pageId=506790682)
- [TDN – Produtos Compostos (B5_PFCOMPO)](https://tdn.totvs.com/pages/viewpage.action?pageId=506790721)
- [TDN – Resíduos Químicos (MV_GRUPRES)](https://tdn.totvs.com/pages/viewpage.action?pageId=506790765)
- [TDN – Conversão de Unidades (MV_CPOMAPA)](https://tdn.totvs.com/pages/viewpage.action?pageId=506987992)
- [TDN – Lista VII (B5_MAPVII)](https://tdn.totvs.com/pages/viewpage.action?pageId=506988257)
- [TDN – Descrição da produção (F5_DESPROD)](https://tdn.totvs.com/pages/viewpage.action?pageId=506994034)
- [TDN – Seção UC: Consumos](https://tdn.totvs.com/pages/releaseview.action?pageId=506993288)
- [TDN – Seção AR: Armazenamento](https://tdn.totvs.com/pages/viewpage.action?pageId=853908754)
- [TDN – MATR947 Mapa de Produtos Controlados – Polícia Civil](https://tdn.totvs.com/x/7FF9IQ)
- [TDN – Relatórios SIGAEST (MATR462, MATR947)](https://tdn.totvs.com/pages/releaseview.action?pageId=745742843)
- [Central TOTVS – MATR949 Configuração Exército](https://centraldeatendimento.totvs.com/hc/pt-br/articles/4402505796247-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-MATR949-Configura%C3%A7%C3%A3o-para-o-Relat%C3%B3rio-Mapa-de-Produtos-Controlados-Comando-Militar-Ex%C3%A9rcito) (conteúdo obtido de trechos indexados; acesso direto bloqueado)
- [Central TOTVS – MATR949 erro "FROM" (MV_MTR949D)](https://centraldeatendimento.totvs.com/hc/pt-br/articles/1500012682362-Cross-Segmento-Backoffice-Linha-Protheus-SIGAEST-MATR949-Error-log-THREAD-ERROR-Sintaxe-incorreta-perto-da-palavra-chave-FROM)
- [Dicionário SB5 – Dados Adicionais do Produto](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sb5.html)
- [Dicionário SB8 – Saldos por Lote](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sb8.html)
- [Dicionário SA5 – Amarração Produto x Fornecedor](https://sempreju.com.br/tabelas_protheus/tabelas/tabela_sa5.html)
- Fontes do pacote: `convertido/matr445_CUSTOM.prx`, `matr330_CUSTOM.prx`, `matr425_CUSTOM.prx`, `matr435_CUSTOM.prx`
