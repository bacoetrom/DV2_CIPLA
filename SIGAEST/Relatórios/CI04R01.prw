#INCLUDE "PROTHEUS.CH"
#INCLUDE "TOPCONN.CH"

/*/{Protheus.doc} CI04R01
Relatório de Balanço de Estoque de Reagentes Controlados (MIT041).

Consolida, por Filial + Produto + Lote + Armazém, as informações regulatórias do
reagente (órgão fiscalizador, nº CAS, FDS, limite de estoque) com o balanço do
período: Saldo Inicial + Compras - Consumo - Perdas/Transferências = Saldo Final.

Base: MATR445 (estrutura TReport / query / CalcEst), MATR425 (filtro de validade
em SB8), MATR435 (CalcEstL por lote) e MATR330 (classificação por CF/CFOP).

Parâmetros (ParamBox - não depende de SX1; respostas salvas no perfil do usuário):
  MV_PAR01 Filial de                C  tam. filial   F3 SM0
  MV_PAR02 Filial até               C  tam. filial   F3 SM0
  MV_PAR03 Período de               D
  MV_PAR04 Período até              D
  MV_PAR05 Grupo de Produto de      C  tam. BM_GRUPO F3 SBM
  MV_PAR06 Grupo de Produto até     C  tam. BM_GRUPO F3 SBM
  MV_PAR07 Produto/Reagente de      C  tam. B1_COD   F3 SB1
  MV_PAR08 Produto/Reagente até     C  tam. B1_COD   F3 SB1
  MV_PAR09 Validade de              D
  MV_PAR10 Validade até             D
  MV_PAR11 Órgãos Fiscalizadores    C  seleção múltipla via f_Opcoes: Polícia Civil,
           Polícia Federal, Exército e NC (não controlado por nenhum deles). A ANVISA
           não entra aqui: marcar qualquer opção de MV_PAR12 já significa ANVISA.
           Padrão: os 3 órgãos marcados e NC desmarcado
  MV_PAR12 Listas ANVISA            C  FILTRO OPCIONAL, seleção múltipla via f_Opcoes:
           as 12 listas da Portaria SVS/MS 344/98 (A1, A2, A3, B1, B2, C1 a C5, D1, D2)
           e NC (produto fora de todas as listas). Padrão: todas marcadas.
           Por ser opcional, nunca bloqueia a emissão: sem nada marcado, ou quando o
           campo da lista não existe no dicionário, o relatório sai sem esse filtro

Nos dois parâmetros o conteúdo é a concatenação dos códigos de 2 posições, com "**" nas
opções não marcadas (ex.: "PF**EX****" = Polícia Federal + Exército). Dentro de cada
parâmetro as opções marcadas são unidas por OR; os dois parâmetros são unidos por AND,
como qualquer outro par de filtros do relatório.

Consequência do AND, decidida com o cliente: produto controlado SÓ pela ANVISA não sai
com o padrão de MV_PAR11 (PC/PF/EX), porque não atende nenhum dos três órgãos. Para
trazê-lo, marque também NC em MV_PAR11 - a condição vira "PC ou PF ou EX ou nenhum
deles" e o recorte passa a ser feito só por MV_PAR12. O texto da opção NC na tela de
seleção avisa isso ao usuário.

Flags de produto controlado na SB5 (configuração padrão TOTVS dos mapas):
  MV_PRODPF  -> campo da Polícia Federal  (ex.: B5_PRODPF)   - MATA950/MATR913
  MV_MTR949A -> campo do Exército         (ex.: B5_PRODEX)   - MATR949
  MV_MTR947A -> campo da Polícia Civil    (ex.: B5_PRODCON)  - MATR947
Opcionais (configuração PF): MV_DESCPR (nome comercial), MV_CODMAPA (cód. SIPROQUIM).

Lista da Portaria SVS/MS 344/98: campo PADRÃO SB1.B1_TPPROD (C 2), o mesmo que o
MATR924 (Livro de Registro Específico) usa para separar os livros - 'A1', 'A2', 'A3',
'B1', 'B2', 'C1' a 'C5', 'D1', 'D2'. É o único indicador de ANVISA usado pelo
relatório: a flag B5_XANVISA deixou de ser consultada quando a opção ANVISA saiu do
grupo de órgãos.

As opções da pergunta MV_PAR12 vêm da tabela genérica SX5_LISTA da SX5 (a mesma do
B1_TPPROD): lista nova ou descrição alterada no cadastro aparece sem recompilar.
Só entram chaves com exatamente 2 posições, porque os códigos são concatenados em
largura fixa. Sem a tabela cadastrada, vale a relação fixa de fListFix.

Campos customizados (SB5): B5_XCAS, B5_XFDS e B5_XLIMEST.

A coluna "Armazenamento / Storage" é o armazém do saldo (B8_LOCAL / B2_LOCAL), e não a
condição de guarda: o B5_XARMAZ deixou de ser consultado quando a coluna de armazém
recebeu esse rótulo.
Todos são opcionais: campo inexistente na SB5 é impresso como "   ". No filtro, a
opção cujo campo não existe é ignorada e registrada no diagnóstico - o resultado
fica mais restrito, nunca mais abrangente. Mas se NENHUMA opção marcada tiver campo
na SB5, a emissão é bloqueada: sem condição de órgão o relatório listaria todo o
estoque como se fosse controlado.

Colunas e campos que saíram do layout continuam no fonte, comentados e marcados com
"[FORA DO LAYOUT]", para facilitar o retorno. São eles:
  PRODUTO (B1_COD)            substituído pelo Nome Comercial, que virou a âncora do total
  SUBLOTE (B8_NUMLOTE)        sem reposição
  LOTEFOR (B8_LOTEFOR)        sem reposição
  ARMAZEN (B5_XARMAZ)         o rótulo "Armazenamento" passou a designar o armazém
  NFDOC/NFSERIE/NFEMIS        consolidados na coluna de Notas Fiscais de Compra
  SLDSIS + CONFERE            checagem de divergência do saldo; nSis ainda é calculado
  Opção AV (B5_XANVISA)       a ANVISA ganhou pergunta própria (MV_PAR12)
Cada ponto traz, no comentário, o que precisa ser reativado junto.

@type Function
@author Pablo Regis
@since  08/10/2026
@version 1.0
/*/

//-- Campos customizados (MIT041 - seção 7.2)
#DEFINE CPO_CAS      "B5_XNCAS"
#DEFINE CPO_FDS      "B5_XFDS"
#DEFINE CPO_LIMEST   "B5_XLIMST"

//-- [FORA DO LAYOUT] Campos que saíram do relatório, mantidos para eventual retorno.
//-- Procure por "[FORA DO LAYOUT]" para achar todos os pontos envolvidos.
//-- B5_XANVISA: flag de produto controlado pela ANVISA. Saiu quando a opção ANVISA deixou
//--   o grupo de órgãos (MV_PAR11) - hoje quem identifica a ANVISA é o B1_TPPROD (MV_PAR12).
// #DEFINE CPO_ANVISA   "B5_XANVISA"
//-- B5_XARMAZ: condição de guarda do reagente ("manter refrigerado", "ao abrigo de luz").
//--   Saiu quando o rótulo "Armazenamento" passou a designar o armazém (B8_LOCAL/B2_LOCAL).
// #DEFINE CPO_ARMAZ    "B5_XARMAZ"

//-- Lista da Portaria SVS/MS 344/98: campo PADRÃO da SB1 (C 2: "A1".."D2"), o mesmo que
//-- o MATR924 (Livro de Registro Específico) usa para classificar o produto por livro.
//-- O nome do campo pode ser trocado pelo parâmetro PAR_LISTA, como nos demais órgãos
#DEFINE CPO_LISTA    "B1_TPPROD"
#DEFINE TAB_LISTA    "SB1"
#DEFINE PAR_LISTA    "MV_XLISANV"
#DEFINE SX5_LISTA    "92"   //-- tabela genérica (SX5) com os códigos do B1_TPPROD

//-- Conteúdo impresso quando o campo não existe na SB5
#DEFINE CPO_VAZIO    "   "

//-- Regras de classificação (MIT041 - seção 6). PERDAS: pendência P1 com o cliente
#DEFINE CF_TRF_ENT   "1151/1152/1552/2151/2152/2552"
#DEFINE CF_TRF_SAI   "5151/5152/5156/5552/6151/6152/6156/6552"
#DEFINE D3_CF_TRANSF "RE4/DE4/RE7/DE7"
#DEFINE TM_PERDAS    "499/999"

//-- Grupos de seleção múltipla (f_Opcoes): órgãos em MV_PAR11, listas da 344/98 em MV_PAR12
#DEFINE ORG_TAM      2      //-- posições do código de cada opção
#DEFINE ORG_NC       "NC"   //-- "não controlado": última opção de cada grupo, não é um órgão/lista
#DEFINE PAR_ORG      11
#DEFINE PAR_LIS      12
#DEFINE QTD_PARAM    12
#DEFINE MAX_DIAS     4095
#DEFINE NUM_PERG     "CI04R01"

//-- Posições do array de opções (mesma estrutura para órgãos e listas)
#DEFINE ORG_COD      1
#DEFINE ORG_DESC     2
#DEFINE ORG_CAMPO    3
#DEFINE ORG_PARAM    4
#DEFINE ORG_PREENCH  5   //-- .T.: controlado quando o campo está preenchido (qualquer conteúdo); .F.: flag = 'S'
#DEFINE ORG_CONTEU   6   //-- preenchido: controlado quando o campo tem este conteúdo (listas da 344/98)
#DEFINE ORG_ALIAS    7   //-- tabela do campo: "SB5" (flags dos órgãos) ou "SB1" (lista da 344/98)

/*/{Protheus.doc} CI04R01
Relatório de agentes controlados
@type function
@version 1.0 
@author Pablo Regis
@since 11/5/2026
/*/
User Function CI04R01()

Local oReport

Private mv_par01, mv_par02, mv_par03, mv_par04, mv_par05, mv_par06, mv_par07, mv_par08
Private mv_par09, mv_par10, mv_par11, mv_par12

If !fParams()
	Return
EndIf

oReport := ReportDef()
oReport:PrintDialog()

Return

/*/{Protheus.doc} fParams
Tela de parâmetros (ParamBox). Também acionada pelo botão "Parâmetros" do TReport.
@type Function
@author Pablo Regis
@since  21/10/2026
@return logical, .T. se confirmado
/*/
Static Function fParams()

Local aPergs  := {}
Local aRet    := {}
Local nTamFil := FWSizeFilial()
Local nTamGrp := TamSX3("BM_GRUPO")[1]
Local nTamPrd := TamSX3("B1_COD")[1]
Local lRet    := .F.
Local nI      := 0

aAdd(aPergs, {1, "Filial de"           , Space(nTamFil)          , "@!", "", "SM0", "", 50, .F.})
aAdd(aPergs, {1, "Filial até"          , Replicate("Z", nTamFil) , "@!", "", "SM0", "", 50, .T.})
aAdd(aPergs, {1, "Período de"          , FirstDate(dDataBase)    , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Período até"         , LastDate(dDataBase)     , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Grupo de Produto de" , Space(nTamGrp)          , "@!", "", "SBM", "", 50, .F.})
aAdd(aPergs, {1, "Grupo de Produto até", Replicate("Z", nTamGrp) , "@!", "", "SBM", "", 50, .T.})
aAdd(aPergs, {1, "Produto/Reagente de" , Space(nTamPrd)          , "@!", "", "SB1", "", 80, .F.})
aAdd(aPergs, {1, "Produto/Reagente até", Replicate("Z", nTamPrd) , "@!", "", "SB1", "", 80, .T.})
aAdd(aPergs, {1, "Validade de"         , StoD("19000101")        , ""  , "", ""   , "", 50, .T.})
aAdd(aPergs, {1, "Validade até"        , StoD("29991231")        , ""  , "", ""   , "", 50, .T.})
//-- Seleção múltipla pelo f_Opcoes: a validação de cada pergunta abre a tela de opções
aAdd(aPergs, {1, "Órgãos Fiscalizadores", fOrgDef(), "@!", "U_CI04ORG()", "", "", 100, .T.})
aAdd(aPergs, {1, "Listas ANVISA"        , fLisDef(), "@!", "U_CI04LIS()", "", "", 100, .F.})

If ParamBox(aPergs, "Parâmetros - Reagentes Controlados", @aRet, , , .T., , , , NUM_PERG, .T., .T.)
	For nI := 1 To QTD_PARAM
		&("mv_par" + StrZero(nI, 2)) := aRet[nI]
	Next nI
	lRet := .T.
EndIf

FwFreeArray(aPergs)

Return lRet

/*/{Protheus.doc} CI04ORG
Validação da pergunta MV_PAR11 (Órgãos Fiscalizadores): abre a seleção múltipla com
o f_Opcoes.

O ParamBox macro-executa o conteúdo da validação, por isso esta rotina precisa ser
User Function (uma Static Function não é visível para o compilador de macros). O
ParamBox informa o nome da variável da pergunta ao TGet (cReadVar), de modo que
ReadVar() devolve "MV_PAR11" durante a validação.

@type Function
@author Pablo Regis
@since  05/11/2026
@return logical, .T. se ao menos uma opção ficou marcada
/*/
User Function CI04ORG()

Local aGrupo := fOrgaos()
//-- O texto do NC orienta quem procura produto controlado só pela ANVISA: como os dois
//-- parâmetros se cruzam por AND, sem o NC aqui o produto só-ANVISA não entra no recorte
Local lRet   := fSelOpc(PAR_ORG, aGrupo, "Órgãos Fiscalizadores", .T., ;
                        "NÃO CONTROLADO POR ESTES ÓRGÃOS (MARQUE PARA VER SÓ ANVISA)")

FwFreeArray(aGrupo)

Return lRet

/*/{Protheus.doc} CI04LIS
Validação da pergunta MV_PAR12 (Listas ANVISA): abre a seleção múltipla com o
f_Opcoes. Vale aqui a mesma observação de CI04ORG sobre ser User Function.
@type Function
@author Pablo Regis
@since  05/11/2026
@return logical, .T. se ao menos uma opção ficou marcada
/*/
User Function CI04LIS()

Local aGrupo := fListas()
Local lRet   := fSelOpc(PAR_LIS, aGrupo, "Listas ANVISA - Portaria 344/98", .F., ;
                        "NÃO CONTROLADO PELA ANVISA (FORA DE TODAS AS LISTAS)")

FwFreeArray(aGrupo)

Return lRet

/*/{Protheus.doc} fSelOpc
Abre o f_Opcoes para um grupo de opções e grava os códigos marcados na pergunta.
Usada pela validação das perguntas MV_PAR11 e MV_PAR12.
@type Function
@author Pablo Regis
@since  05/11/2026
@param nParam, numeric, número da pergunta (PAR_ORG ou PAR_LIS)
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cTitulo, character, título da coluna de opções na tela do f_Opcoes
@param lObrig, logical, .T. exige ao menos uma opção marcada para sair do campo
@param cDescNC, character, descrição da opção NC na tela deste grupo
@return logical, .T. se o campo pode perder o foco
/*/
Static Function fSelOpc(nParam, aGrupo, cTitulo, lObrig, cDescNC)

Local aOpcoes  := {}
Local cCodigos := ""
Local cVar     := AllTrim(ReadVar())
Local cSel     := ""
Local lRet     := .T.

//-- Fora do contexto do get (ReadVar vazio) a pergunta é endereçada pelo nome
If Empty(cVar)
	cVar := "MV_PAR" + StrZero(nParam, 2)
EndIf

aOpcoes := fOpcGrp(aGrupo, @cCodigos, cDescNC)

//-- Conteúdo atual: o f_Opcoes marca as opções já presentes na variável
If Type(cVar) == "C"
	cSel := &(cVar)
EndIf

If f_Opcoes(@cSel, cTitulo, aOpcoes, cCodigos, , , .F., ORG_TAM, Len(aOpcoes))
	&(cVar) := cSel
EndIf

//-- Grupo opcional: deixar tudo desmarcado é uma escolha válida (não filtra por ele)
If lObrig
	lRet := !Empty(fSelGrp(nParam, aGrupo))
	If !lRet
		Help(NIL, NIL, NUM_PERG, NIL, "Selecione ao menos uma opção em " + cTitulo + ".", 1, 0, NIL, NIL, NIL, NIL, NIL, ;
		     {"Marque uma das opções na tela de seleção."})
	EndIf
EndIf

FwFreeArray(aOpcoes)

Return lRet

/*/{Protheus.doc} ReportDef
Definição do layout (colunas bilíngues PT/EN).
/*/
Static Function ReportDef()

Local oReport
Local oSecao
Local oBreak
Local cPictQtd := PesqPict("SB8", "B8_SALDO")
Local nTamQtd  := TamSX3("B8_SALDO")[1] + 4
Local cTitulo  := "Balanço de Estoque de Reagentes Controlados / Controlled Reagents Stock Balance"
Local cDescri  := "Consolida as informações regulatórias dos reagentes controlados com o balanço de " + ;
                  "estoque do período (saldo inicial, compras, consumo, perdas/transferências e saldo final)."

oReport := TReport():New(NUM_PERG, cTitulo, {|| fParams()}, {|oRep| ReportPrint(oRep)}, cDescri)
oReport:SetLandscape()
oReport:SetTotalInLine(.F.)

oSecao := TRSection():New(oReport, "Reagentes controlados / Controlled reagents", {"SB8", "SB1", "SB5"})
oSecao:SetTotalInLine(.F.)
oSecao:SetHeaderPage(.T.)

//-- Identificação
TRCell():New(oSecao, "LINHA"   , "", "Linha"                    + "/" + "Line"                       , "@E 999999", 6, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "FILIAL"  , "", "Filial"                   + "/" + "Branch"                     , "@!", FWSizeFilial())
TRCell():New(oSecao, "CONTROL" , "", "Controlado"               + "/" + "Controlled"                 , "@!", 12)

//-- Regulatório
TRCell():New(oSecao, "ORGAO"   , "", "Órgão Fiscalizador"       + "/" + "Surveillance Body"          , "@!", 30)
TRCell():New(oSecao, "LIMEST"  , "", "Limite de Estoque"        + "/" + "Stock Limit"                , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")

//-- Identificação do reagente
//-- [FORA DO LAYOUT] Código do produto (B1_COD). O produto passou a ser identificado pelo
//-- Nome Comercial, que também virou a âncora da quebra de total. Para voltar, reative
//-- aqui, o oItem["PRODUTO"] em fMontaItem, o nome em fImprime e o TRBreak abaixo.
// TRCell():New(oSecao, "PRODUTO" , "", "Código"                   + "/" + "Code"                       , "@!", TamSX3("B1_COD")[1])
TRCell():New(oSecao, "CODMAPA" , "", "Código do Reagente"       + "/" + "Reagent Code"               , "@!", 18)
TRCell():New(oSecao, "NOMECOM" , "", "Nome Comercial (Rótulo)"  + "/" + "Commercial Name (Label)"    , "@!", 30)
TRCell():New(oSecao, "NOMEQUI" , "", "Nome Químico (Português)" + "/" + "Chemical Name (Portuguese)" , "@!", 30)
TRCell():New(oSecao, "CAS"     , "", "Número CAS"               + "/" + "CAS Number"                 , "@!", 12)
TRCell():New(oSecao, "FORMA"   , "", "Forma"                    + "/" + "Form"                       , "@!", 10)
TRCell():New(oSecao, "FABRIC"  , "", "Fabricante"               + "/" + "Manufacturer"               , "@!", 30)
TRCell():New(oSecao, "LOTE"    , "", "Lote"                     + "/" + "Batch"                      , "@!", TamSX3("B8_LOTECTL")[1])
//-- [FORA DO LAYOUT] Sub-lote e lote do fornecedor. Sem a coluna de sub-lote, produtos com
//-- rastro "S" geram uma linha por sub-lote que fica visualmente idêntica às demais.
// TRCell():New(oSecao, "SUBLOTE" , "", "Sub-Lote"                 + "/" + "Sub-Batch"                  , "@!", TamSX3("B8_NUMLOTE")[1])
// TRCell():New(oSecao, "LOTEFOR" , "", "Lote Fabric."             + "/" + "Mfr. Batch"                 , "@!", TamSX3("B8_LOTEFOR")[1])
TRCell():New(oSecao, "FDS"     , "", "FDS"                      + "/" + "SDS"                        , "@!", 20)
//-- "Armazenamento" é o armazém/depósito do saldo (B8_LOCAL / B2_LOCAL), não a
//-- condição de guarda: o rótulo mudou, a origem do dado continua sendo o depósito
TRCell():New(oSecao, "ARMAZEM" , "", "Armazenamento"            + "/" + "Storage"                    , "@!", 20)
//-- [FORA DO LAYOUT] Condição de guarda do reagente (B5_XARMAZ), que ocupava o rótulo
//-- "Armazenamento" antes de ele passar a designar o armazém. Se as duas informações
//-- precisarem conviver, reative com um rótulo próprio (ex.: "Condições de Armazenamento").
// TRCell():New(oSecao, "ARMAZEN" , "", "Condições de Armazenamento" + "/" + "Storage Conditions"     , "@!", 20)
TRCell():New(oSecao, "DTFABRIC", "", "Data de Fabricação"       + "/" + "Manufacture Date"           , "@D", 10)
TRCell():New(oSecao, "DTVALID" , "", "Data de Validade"         + "/" + "Expiry Date"                , "@D", 10)
TRCell():New(oSecao, "UM"      , "", "Unidade de Medida"        + "/" + "Unit of Measure"            , "@!", TamSX3("B1_UM")[1])

//-- Balanço do período
TRCell():New(oSecao, "SLDINI"  , "", "Estoque Inicial do Mês"   + "/" + "Initial Monthly Inventory"  , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "COMPRAS" , "", "Quantidade Comprada"      + "/" + "Quantity Purchased"         , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "NFCOMPRA", "", "Notas Fiscais de Compra (Número, Fornecedor e Data)" + "/" + ;
                                     "Purchase Invoices (Number, Vendor and Date)"                   , "@!", 50)
//-- [FORA DO LAYOUT] As três colunas separadas da NF, consolidadas na coluna acima
//-- (fNFCompra). O fornecedor não existia como coluna e só passou a sair na consolidada.
// TRCell():New(oSecao, "NFDOC"   , "", "NF Compra"                + "/" + "Purchase Inv."              , "@!", TamSX3("B8_DOC")[1])
// TRCell():New(oSecao, "NFSERIE" , "", "Série"                    + "/" + "Series"                     , "@!", TamSX3("B8_SERIE")[1])
// TRCell():New(oSecao, "NFEMIS"  , "", "Emissão NF"               + "/" + "Inv. Date"                  , "@D", 10)
TRCell():New(oSecao, "CONSUMO" , "", "Quantidade Utilizada no Mês" + "/" + "Quantity Used During the Month", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "PERDAS"  , "", "Perdas e Transferências"  + "/" + "Losses and Transfers"       , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDFIM"  , "", "Estoque Final"            + "/" + "Final Inventory"            , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
//-- [FORA DO LAYOUT] Conferência do saldo: "Estoque Final" é o saldo CALCULADO
//-- (inicial + compras - consumo - perdas) e "Saldo Sistema" era o saldo real na data
//-- final; a coluna "Conferência" comparava os dois e acusava DIVERGENTE. O nSis continua
//-- sendo calculado em fMontaItem, então basta reativar estas duas colunas e os
//-- respectivos oItem[] para ter a checagem de volta.
// TRCell():New(oSecao, "SLDSIS"  , "", "Saldo Sistema"            + "/" + "System Balance"             , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
// TRCell():New(oSecao, "CONFERE" , "", "Conferência"              + "/" + "Check"                      , "@!", 10)

//-- Responsabilidade (preenchimento manual)
TRCell():New(oSecao, "RESP"    , "", "Responsável"              + "/" + "Responsible Person"         , "@!", 15)
TRCell():New(oSecao, "CONFER"  , "", "Conferente"               + "/" + "Checker"                    , "@!", 15)
TRCell():New(oSecao, "OBS"     , "", "Observações"              + "/" + "Notes"                      , "@!", 20)

//-- Totais por produto (unidades diferentes entre produtos: sem total geral).
//-- O produto é identificado pelo Nome Comercial, que substituiu a coluna de código
oBreak := TRBreak():New(oSecao, oSecao:Cell("NOMECOM"), "Total do produto / Product total", .F.)
//-- [FORA DO LAYOUT] Quebra original, pelo código do produto. Reativar junto com a
//-- coluna PRODUTO: agrupa pelo código, que é exato, em vez do nome comercial.
// oBreak := TRBreak():New(oSecao, oSecao:Cell("PRODUTO"), "Total do produto / Product total", .F.)
TRFunction():New(oSecao:Cell("SLDINI" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("COMPRAS"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("CONSUMO"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("PERDAS" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("SLDFIM" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)

Return oReport

/*/{Protheus.doc} ReportPrint
Valida os filtros, percorre as filiais do intervalo e imprime.
@type function
@version 1.0  
@author Pablo Regis
@since 11/5/2026
/*/
Static Function ReportPrint(oReport)

Local oSecao   := oReport:Section(1)
Local aSM0     := {}
Local aFiliais := {}
Local aOrgaos  := {}
Local aListas  := {}
Local oCfg     := Nil
Local cCondOrg := ""
Local cErro    := ""
Local cIgnora  := ""
Local cFilBak  := cFilAnt
Local oDiag    := JsonObject():New()
Local nI       := 0

oDiag["FILIAIS"  ] := ""
oDiag["LIDOS"    ] := 0
oDiag["DESCART"  ] := 0
oDiag["IMPRESSOS"] := 0
oDiag["EXEMPLO"  ] := ""
oDiag["ORGIGN"   ] := ""

aOrgaos := fOrgaos()
aListas := fListas()

If !fValida(aOrgaos, aListas, @cCondOrg, @cErro, @cIgnora)
	Help(NIL, NIL, NUM_PERG, NIL, cErro, 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros do relatório."})
	oReport:CancelPrint()
	Return
EndIf

//-- Opções sem campo na SB5 ficam fora do filtro (apenas registrado no diagnóstico)
If Empty(cIgnora)
	oDiag["ORGIGN"] := "nenhum"
Else
	oDiag["ORGIGN"] := cIgnora
EndIf

//-- Registra sempre o que foi marcado e a condição gerada. Sem isso, divergência entre
//-- o que o usuário marcou e o que a query filtrou só aparece quando nada é impresso
FWLogMsg("INFO", , NUM_PERG, FunName(), "", "01", ;
         "MV_PAR11=[" + cValToChar(mv_par11) + "] MV_PAR12=[" + cValToChar(mv_par12) + "] " + ;
         "Campos: " + fCpoOrg(aOrgaos) + fCpoOrg(aListas) + ;
         "Fora do filtro: " + oDiag["ORGIGN"] + " | Condicao: " + cCondOrg, 0, 0, {})

aSM0 := FWLoadSM0()
For nI := 1 To Len(aSM0)
	If aSM0[nI][SM0_GRPEMP] == cEmpAnt .And. ;
	   aSM0[nI][SM0_CODFIL] >= mv_par01 .And. aSM0[nI][SM0_CODFIL] <= mv_par02
		aAdd(aFiliais, aSM0[nI][SM0_CODFIL])
	EndIf
Next nI

If Empty(aFiliais)
	Help(NIL, NIL, NUM_PERG, NIL, "Nenhuma filial encontrada no intervalo informado.", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros Filial de / Filial até."})
	oReport:CancelPrint()
	Return
EndIf

oCfg := fConfig()

oReport:SetTitle(oReport:Title() + " - " + DtoC(mv_par03) + " a " + DtoC(mv_par04))
oReport:SetMeter(Len(aFiliais))
oSecao:Init()

For nI := 1 To Len(aFiliais)
	If oReport:Cancel()
		Exit
	EndIf
	cFilAnt := aFiliais[nI]        //-- CalcEst/CalcEstL e xFilial() usam a filial corrente
	oReport:IncMeter()
	fProcFil(oReport, oSecao, aOrgaos, aListas, cCondOrg, oCfg, oDiag)
Next nI

oSecao:Finish()
cFilAnt := cFilBak

//-- Nada impresso: mostra onde os registros foram descartados
If oDiag["IMPRESSOS"] == 0 .And. !oReport:Cancel()
	Help(NIL, NIL, NUM_PERG, NIL, ;
	     "Nenhuma linha impressa." + CRLF + ;
	     "Filiais processadas: " + oDiag["FILIAIS"] + CRLF + ;
	     "Registros lidos nas consultas: " + cValToChar(oDiag["LIDOS"]) + CRLF + ;
	     "Descartados (sem saldo e sem movimento): " + cValToChar(oDiag["DESCART"]) + CRLF + ;
	     "Exemplo descartado: " + oDiag["EXEMPLO"] + CRLF + ;
	     "Grupos com opção fora do filtro (campo inexistente na SB5): " + oDiag["ORGIGN"] + CRLF + ;
	     "Filtro de órgãos e listas: " + cCondOrg, ;
	     1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros e o cadastro dos produtos controlados."})
EndIf

FreeObj(oDiag)

FwFreeArray(aSM0)
FwFreeArray(aFiliais)

Return

/*/{Protheus.doc} fValida
Validação dos filtros obrigatórios (fluxo alternativo A1) e montagem da condição dos
dois grupos de seleção. Cada grupo é resolvido por fCondGrp (opções unidas por OR) e
os dois são unidos por AND, como qualquer outro par de filtros do relatório.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrgaos, array, grupo dos órgãos fiscalizadores (fOrgaos)
@param aListas, array, grupo das listas da ANVISA (fListas)
@param cCondOrg, character, retorna a condição SQL dos dois grupos (por referência)
@param cErro, character, retorna a mensagem de erro (por referência)
@param cIgnora, character, retorna os grupos com opção fora do filtro (por referência)
@return logical, .T. se os parâmetros são válidos
/*/
Static Function fValida(aOrgaos, aListas, cCondOrg, cErro, cIgnora)

Local cOrg    := fSelGrp(PAR_ORG, aOrgaos)
Local cLis    := fSelGrp(PAR_LIS, aListas)
Local cCndOrg := ""
Local cCndLis := ""
Local lRet    := .T.

Do Case
Case Empty(mv_par02)
	cErro := "Informe o parâmetro Filial até."
Case mv_par01 > mv_par02
	cErro := "Filial de maior que Filial até."
Case Empty(mv_par03) .Or. Empty(mv_par04)
	cErro := "Informe o Período de e o Período até."
Case mv_par03 > mv_par04
	cErro := "Período de maior que Período até."
Case (mv_par04 - mv_par03) > MAX_DIAS
	cErro := "O período não pode ultrapassar " + cValToChar(MAX_DIAS) + " dias."
Case Empty(mv_par06)
	cErro := "Informe o parâmetro Grupo de Produto até."
Case mv_par05 > mv_par06
	cErro := "Grupo de Produto de maior que Grupo de Produto até."
Case Empty(mv_par08)
	cErro := "Informe o parâmetro Produto/Reagente até."
Case mv_par07 > mv_par08
	cErro := "Produto/Reagente de maior que Produto/Reagente até."
Case Empty(mv_par09) .Or. Empty(mv_par10)
	cErro := "Informe a Validade de e a Validade até."
Case mv_par09 > mv_par10
	cErro := "Validade de maior que Validade até."
Case Empty(cOrg)
	cErro := "Selecione ao menos uma opção em Órgãos Fiscalizadores."
EndCase

lRet := Empty(cErro)

//-- Uma condição por grupo; os dois grupos são unidos por AND
If lRet
	lRet := fCondGrp(aOrgaos, cOrg, "Órgãos Fiscalizadores", .T., @cCndOrg, @cErro, @cIgnora)
EndIf

//-- Listas ANVISA é filtro opcional: nunca bloqueia a emissão
If lRet
	lRet := fCondGrp(aListas, cLis, "Listas ANVISA", .F., @cCndLis, @cErro, @cIgnora)
EndIf

If lRet
	cCondOrg := "(" + cCndOrg + " AND " + cCndLis + ")"
EndIf

Return lRet

/*/{Protheus.doc} fCpoOrg
Pares "código=campo" de um grupo, para o log de diagnóstico. Campo vazio significa
parâmetro não configurado ou campo inexistente na SB5 - ou seja, opção fora do filtro.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@return character, pares separados por espaço
/*/
Static Function fCpoOrg(aGrupo)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aGrupo)
	cRet += aGrupo[nI][ORG_COD] + "="
	If Empty(aGrupo[nI][ORG_CAMPO])
		cRet += "<sem campo> "
	Else
		cRet += aGrupo[nI][ORG_ALIAS] + "." + AllTrim(aGrupo[nI][ORG_CAMPO]) + " "
	EndIf
Next nI

Return cRet

/*/{Protheus.doc} fCondGrp
Condição SQL de um grupo de opções: as opções marcadas são unidas por OR e a opção NC
nega todas as regras do grupo (produto fora dele).

Grupo sem nada marcado não filtra: a condição vira "1 = 1".

Opção cujo campo não existe na SB5 sai da condição e o grupo é registrado em cIgnora -
o resultado fica mais restrito, nunca mais abrangente. Se nenhuma opção marcada tiver
campo, o critério é:
  - grupo opcional (lObrig = .F.), ou todas as opções marcadas: a condição vira
    "1 = 1" e o relatório sai sem esse filtro;
  - grupo obrigatório com seleção parcial: aborta, porque "1 = 1" devolveria todo o
    estoque no lugar do recorte pedido.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cSel, character, códigos marcados (fSelGrp)
@param cGrupo, character, nome do grupo para as mensagens
@param lObrig, logical, .T. aborta quando o recorte pedido não pode ser aplicado
@param cCond, character, retorna a condição SQL do grupo (por referência)
@param cErro, character, retorna a mensagem de erro (por referência)
@param cIgnora, character, acumula os grupos com opção fora do filtro (por referência)
@return logical, .T. se a condição pôde ser montada
/*/
Static Function fCondGrp(aGrupo, cSel, cGrupo, lObrig, cCond, cErro, cIgnora)

Local aCond := {}
Local aNeg  := {}
Local cCod  := ""
Local nI    := 0
Local nPos  := 0
Local nSel  := Len(cSel) / ORG_TAM
Local lIgn  := .F.
Local lRet  := .T.

For nI := 1 To Len(cSel) Step ORG_TAM
	If !lRet
		Exit
	EndIf
	cCod := SubStr(cSel, nI, ORG_TAM)
	If cCod == ORG_NC
		//-- Fora do grupo: nenhuma das regras configuradas se aplica ao produto
		aNeg := {}
		For nPos := 1 To Len(aGrupo)
			If !Empty(aGrupo[nPos][ORG_CAMPO])
				aAdd(aNeg, fCondOrg(aGrupo[nPos], .F.))
			EndIf
		Next nPos
		If Empty(aNeg)
			lIgn := .T.
		Else
			aAdd(aCond, "(" + fJunta(aNeg, " AND ") + ")")
		EndIf
	Else
		nPos := aScan(aGrupo, {|x| x[ORG_COD] == cCod})
		If nPos == 0
			cErro := "Código inválido em " + cGrupo + ": " + cCod + "."
			lRet  := .F.
		ElseIf Empty(aGrupo[nPos][ORG_CAMPO])
			//-- Campo inexistente na SB5 (ou parâmetro vazio): a opção sai do filtro
			lIgn := .T.
		Else
			aAdd(aCond, fCondOrg(aGrupo[nPos], .T.))
		EndIf
	EndIf
Next nI

If lRet
	Do Case
	Case !Empty(aCond)
		cCond := "(" + fJunta(aCond, " OR ") + ")"
	Case !lObrig .Or. Empty(cSel) .Or. nSel >= (Len(aGrupo) + 1)
		//-- Grupo opcional, nada marcado ou tudo marcado: não restringe nada
		cCond := "(1 = 1)"
	OtherWise
		cErro := "Nenhuma opção marcada em " + cGrupo + " tem campo correspondente no dicionário." + CRLF + ;
		         "Sem isso o relatório listaria todo o estoque no lugar do recorte pedido."
		lRet  := .F.
	EndCase
EndIf

If lIgn
	If Empty(cIgnora)
		cIgnora := cGrupo
	Else
		cIgnora += ", " + cGrupo
	EndIf
EndIf

FwFreeArray(aNeg)
FwFreeArray(aCond)

Return lRet

/*/{Protheus.doc} fProcFil
Processa a filial corrente: produtos com rastro (SB8) e sem rastro (SB2).
/*/
Static Function fProcFil(oReport, oSecao, aOrgaos, aListas, cCondOrg, oCfg, oDiag)

Local oMov     := fCarregaMov()
Local oCache   := JsonObject():New()
Local oItem    := Nil
Local cAlias   := GetNextAlias()
Local cQry     := ""
Local cChave   := ""
Local cChvAnt  := ""
Local lSubLote := .F.

oDiag["FILIAIS"] += "[" + cFilAnt + " SB8='" + xFilial("SB8") + "' SB1='" + xFilial("SB1") + ;
                    "' SB5='" + xFilial("SB5") + "'] "

//-- 1) Produtos com rastro de lote/sublote: um registro por Produto + Armazém + Lote (+ Sub-Lote)
cQry := "SELECT SB8.B8_PRODUTO PRODUTO, SB8.B8_LOCAL ARMAZEM, SB8.B8_LOTECTL LOTE, SB8.B8_NUMLOTE SUBLOTE, "
cQry += "       SB8.B8_DTVALID DTVALID, SB8.B8_DFABRIC DTFABRIC, SB8.B8_LOTEFOR LOTEFOR, "
cQry += "       SB8.B8_DOC DOC, SB8.B8_SERIE SERIE, SB8.B8_CLIFOR CLIFOR, SB8.B8_LOJA LOJA, SB8.B8_ORIGLAN ORIGLAN, "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "  FROM " + RetSqlName("SB8") + " SB8 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' "
cQry += "       AND SB1.B1_COD = SB8.B8_PRODUTO AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON SB5.B5_FILIAL = '" + xFilial("SB5") + "' "
cQry += "       AND SB5.B5_COD = SB8.B8_PRODUTO AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE SB8.B8_FILIAL = '" + xFilial("SB8") + "' "
cQry += "   AND SB8.B8_PRODUTO BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB8.B8_DTVALID BETWEEN '" + DtoS(mv_par09) + "' AND '" + DtoS(mv_par10) + "' "
cQry += "   AND SB1.B1_RASTRO IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB8.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB8.B8_PRODUTO, SB8.B8_LOCAL, SB8.B8_LOTECTL, SB8.B8_NUMLOTE, SB8.B8_DATA "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "DTVALID" , "D", 8, 0)
TcSetField(cAlias, "DTFABRIC", "D", 8, 0)
TcSetField(cAlias, "EMAX"    , "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()

	lSubLote := (cAlias)->RASTRO == "S"
	cChave   := fChave((cAlias)->PRODUTO, (cAlias)->ARMAZEM, (cAlias)->LOTE, If(lSubLote, (cAlias)->SUBLOTE, ""))

	//-- Rastro por lote pode ter mais de um SB8 para o mesmo lote: usa o primeiro (entrada mais antiga)
	If cChave <> cChvAnt
		cChvAnt := cChave
		oDiag["LIDOS"] += 1
		oItem   := fMontaItem(cAlias, .T., lSubLote, oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)
		If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
			//-- Sequencial contínuo da coluna "Linha": reaproveita o contador de impressos
			oDiag["IMPRESSOS"] += 1
			oItem["LINHA"] := oDiag["IMPRESSOS"]
			fImprime(oSecao, oItem)
			FreeObj(oItem)
		EndIf
	EndIf

	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

//-- 2) Produtos controlados sem rastro: um registro por Produto + Armazém (validade não se aplica)
cAlias := GetNextAlias()
cQry := "SELECT SB2.B2_COD PRODUTO, SB2.B2_LOCAL ARMAZEM, "
cQry += "       SB1.B1_DESC DESCRI, SB1.B1_UM UM, SB1.B1_RASTRO RASTRO, SB1.B1_EMAX EMAX "
cQry += "  FROM " + RetSqlName("SB2") + " SB2 "
cQry += " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' "
cQry += "       AND SB1.B1_COD = SB2.B2_COD AND SB1.D_E_L_E_T_ = ' ' "
cQry += "  LEFT JOIN " + RetSqlName("SB5") + " SB5 ON SB5.B5_FILIAL = '" + xFilial("SB5") + "' "
cQry += "       AND SB5.B5_COD = SB2.B2_COD AND SB5.D_E_L_E_T_ = ' ' "
cQry += " WHERE SB2.B2_FILIAL = '" + xFilial("SB2") + "' "
cQry += "   AND SB2.B2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' "
cQry += "   AND SB1.B1_RASTRO NOT IN ('L','S') "
cQry += "   AND " + cCondOrg + " "
cQry += "   AND SB2.D_E_L_E_T_ = ' ' "
cQry += " ORDER BY SB2.B2_COD, SB2.B2_LOCAL "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "EMAX", "N", TamSX3("B1_EMAX")[1], TamSX3("B1_EMAX")[2])

While !(cAlias)->(Eof()) .And. !oReport:Cancel()
	cChave := fChave((cAlias)->PRODUTO, (cAlias)->ARMAZEM, "", "")
	oDiag["LIDOS"] += 1
	oItem  := fMontaItem(cAlias, .F., .F., oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)
	If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
		oDiag["IMPRESSOS"] += 1
		oItem["LINHA"] := oDiag["IMPRESSOS"]
		fImprime(oSecao, oItem)
		FreeObj(oItem)
	EndIf
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

FreeObj(oMov)
FreeObj(oCache)

Return

/*/{Protheus.doc} fCarregaMov
Movimentos do período da filial corrente, agregados por Produto + Armazém + Lote + Sub-Lote
e classificados em Compras / Consumo / Perdas-Transferências (MIT041 - seção 6).
Retorna JsonObject: chave -> {nCompras, nConsumo, nPerdas}.
/*/
Static Function fCarregaMov()

Local oMov      := JsonObject():New()
Local cAlias    := GetNextAlias()
Local cQry      := ""
Local cIni      := DtoS(mv_par03)
Local cFim      := DtoS(mv_par04)
Local cCfTrE    := fSqlIn(CF_TRF_ENT)
Local cCfTrS    := fSqlIn(CF_TRF_SAI)
Local cCfD3Tr   := fSqlIn(D3_CF_TRANSF)
Local cTmPerda  := fSqlIn(TM_PERDAS)
Local cPerdaD3  := ""
Local cProdD3   := ""
Local cWhereD3  := ""
Local cJoinB1   := ""
Local lWmsNew   := SuperGetMv("MV_WMSNEW", .F., .F.)
Local lD3Servi  := IIf(lWmsNew, .F., GetMV("MV_D3SERVI", .F., "N") == "N")

cPerdaD3 := "(D3_CF IN (" + cCfD3Tr + ") OR D3_TM IN (" + cTmPerda + "))"
cProdD3  := "(D3_CF LIKE 'PR%' OR D3_CF LIKE 'ER%')"

//-- Mesmo filtro de WMS do MATR445
If lD3Servi .And. IntDL()
	cWhereD3 := " AND ( (D3_SERVIC = '   ') OR (D3_SERVIC <> '   ' AND D3_TM <= '500') OR "
	cWhereD3 += " (D3_SERVIC <> '   ' AND D3_TM > '500' AND D3_LOCAL = '" + GetMvNNR("MV_CQ", "98") + "') ) "
EndIf

cJoinB1 := " INNER JOIN " + RetSqlName("SB1") + " SB1 ON SB1.B1_FILIAL = '" + xFilial("SB1") + "' AND SB1.D_E_L_E_T_ = ' ' "
cJoinB1 += " AND SB1.B1_GRUPO BETWEEN '" + mv_par05 + "' AND '" + mv_par06 + "' AND SB1.B1_COD = "

cQry := "SELECT COD, LOC, LOTE, SUBLOTE, SUM(COMPRAS) COMPRAS, SUM(CONSUMO) CONSUMO, SUM(PERDAS) PERDAS FROM ( "

//-- SD1: compras (+), devolução de venda (- consumo), transferência recebida (- perdas/transf.)
cQry += "SELECT D1_COD COD, D1_LOCAL LOC, D1_LOTECTL LOTE, D1_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF NOT IN (" + cCfTrE + ") THEN D1_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D1_TIPO = 'D' THEN -D1_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D1_TIPO <> 'D' AND D1_CF IN (" + cCfTrE + ") THEN -D1_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD1") + " SD1 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON SF4.F4_FILIAL = '" + xFilial("SF4") + "' "
cQry += "       AND SF4.F4_CODIGO = SD1.D1_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += cJoinB1 + "SD1.D1_COD "
cQry += " WHERE SD1.D1_FILIAL = '" + xFilial("SD1") + "' "
cQry += "   AND SD1.D1_DTDIGIT BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD1.D1_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD1.D1_ORIGLAN <> 'LF' AND SD1.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD2: vendas (+ consumo), devolução de compra (- compras), transferência enviada (+ perdas/transf.)
cQry += "SELECT D2_COD COD, D2_LOCAL LOC, D2_LOTECTL LOTE, D2_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D2_TIPO = 'D' THEN -D2_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF NOT IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN D2_TIPO <> 'D' AND D2_CF IN (" + cCfTrS + ") THEN D2_QUANT ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD2") + " SD2 "
cQry += " INNER JOIN " + RetSqlName("SF4") + " SF4 ON SF4.F4_FILIAL = '" + xFilial("SF4") + "' "
cQry += "       AND SF4.F4_CODIGO = SD2.D2_TES AND SF4.F4_ESTOQUE = 'S' AND SF4.D_E_L_E_T_ = ' ' "
cQry += cJoinB1 + "SD2.D2_COD "
cQry += " WHERE SD2.D2_FILIAL = '" + xFilial("SD2") + "' "
cQry += "   AND SD2.D2_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD2.D2_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD2.D2_ORIGLAN <> 'LF' AND SD2.D_E_L_E_T_ = ' ' "

cQry += "UNION ALL "

//-- SD3: produção (+ compras/entradas), transferências e TMs de perda (perdas/transf.), demais (consumo)
cQry += "SELECT D3_COD COD, D3_LOCAL LOC, D3_LOTECTL LOTE, D3_NUMLOTE SUBLOTE, "
cQry += "  CASE WHEN D3_CF LIKE 'PR%' THEN D3_QUANT WHEN D3_CF LIKE 'ER%' THEN -D3_QUANT ELSE 0 END COMPRAS, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND NOT " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END CONSUMO, "
cQry += "  CASE WHEN NOT " + cProdD3 + " AND " + cPerdaD3
cQry += "       THEN (CASE WHEN D3_TM > '500' THEN D3_QUANT ELSE -D3_QUANT END) ELSE 0 END PERDAS "
cQry += "  FROM " + RetSqlName("SD3") + " SD3 "
cQry += cJoinB1 + "SD3.D3_COD "
cQry += " WHERE SD3.D3_FILIAL = '" + xFilial("SD3") + "' "
cQry += "   AND SD3.D3_EMISSAO BETWEEN '" + cIni + "' AND '" + cFim + "' "
cQry += "   AND SD3.D3_COD BETWEEN '" + mv_par07 + "' AND '" + mv_par08 + "' "
cQry += "   AND SD3.D3_ESTORNO <> 'S' AND SD3.D_E_L_E_T_ = ' ' "
cQry += cWhereD3

cQry += ") MOV GROUP BY COD, LOC, LOTE, SUBLOTE "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
TcSetField(cAlias, "COMPRAS", "N", 18, 4)
TcSetField(cAlias, "CONSUMO", "N", 18, 4)
TcSetField(cAlias, "PERDAS" , "N", 18, 4)

While !(cAlias)->(Eof())
	oMov[fChave((cAlias)->COD, (cAlias)->LOC, (cAlias)->LOTE, (cAlias)->SUBLOTE)] := ;
		{(cAlias)->COMPRAS, (cAlias)->CONSUMO, (cAlias)->PERDAS}
	(cAlias)->(DbSkip())
EndDo
(cAlias)->(DbCloseArea())

Return oMov

/*/{Protheus.doc} fMontaItem
Calcula o balanço do item e reúne as informações regulatórias. Retorna Nil quando
não há saldo nem movimento no período.
/*/
Static Function fMontaItem(cAlias, lLote, lSubLote, oMov, cChave, aOrgaos, aListas, oCfg, oCache, oDiag)

Local oItem    := Nil
Local cProd    := (cAlias)->PRODUTO
Local cLocal   := (cAlias)->ARMAZEM
Local cLote    := ""
Local cSubLote := Nil
Local aMov     := oMov[cChave]
Local nIni     := 0
Local nSis     := 0
Local nFim     := 0
Local cEstMat  := ""
Local cControl := ""
Local xLimite  := Nil

If ValType(aMov) <> "A"
	aMov := {0, 0, 0}
EndIf

If lLote
	cLote    := (cAlias)->LOTE
	cSubLote := If(lSubLote, (cAlias)->SUBLOTE, Nil)
	nIni     := CalcEstL(cProd, cLocal, mv_par03    , cLote, cSubLote)[1]
	nSis     := CalcEstL(cProd, cLocal, mv_par04 + 1, cLote, cSubLote)[1]
Else
	nIni     := CalcEst(cProd, cLocal, mv_par03)[1]
	nSis     := CalcEst(cProd, cLocal, mv_par04 + 1)[1]
EndIf

//-- Sem saldo e sem movimento no período: não imprime
If nIni == 0 .And. nSis == 0 .And. aMov[1] == 0 .And. aMov[2] == 0 .And. aMov[3] == 0
	oDiag["DESCART"] += 1
	If Empty(oDiag["EXEMPLO"])
		oDiag["EXEMPLO"] := cFilAnt + " / " + AllTrim(cProd) + " / " + cLocal + " / " + AllTrim(cLote) + ;
		                    " (Sld. " + DtoC(mv_par03) + " = " + cValToChar(nIni) + ;
		                    ", Sld. " + DtoC(mv_par04 + 1) + " = " + cValToChar(nSis) + ")"
	EndIf
	Return Nil
EndIf

nFim := nIni + aMov[1] - aMov[2] - aMov[3]

SB5->(DbSetOrder(1))
SB5->(MsSeek(xFilial("SB5") + cProd))

//-- A lista da 344/98 fica na SB1 (B1_TPPROD), lida por fDescOrg junto com as flags da SB5
SB1->(DbSetOrder(1))
SB1->(MsSeek(xFilial("SB1") + cProd))

oItem := JsonObject():New()
oItem["FILIAL"  ] := cFilAnt
//-- [FORA DO LAYOUT] Código do produto, hoje sem coluna
// oItem["PRODUTO" ] := cProd
//-- Nome Comercial identifica o produto no layout (não há coluna de código)
oItem["NOMECOM" ] := fCpoSB5(oCfg["DESCPR"], "")
If Empty(oItem["NOMECOM"])
	oItem["NOMECOM"] := (cAlias)->DESCRI
EndIf
oItem["NOMEQUI" ] := fCpoSB5("B5_CEME", CPO_VAZIO)
oItem["CAS"     ] := fCpoSB5(CPO_CAS, CPO_VAZIO)
oItem["CODMAPA" ] := fCpoSB5(oCfg["CODMAPA"], CPO_VAZIO)
cEstMat := fCpoSB5("B5_ESTMAT", "")
If Empty(cEstMat)
	oItem["FORMA"   ] := CPO_VAZIO
Else
	oItem["FORMA"   ] := X3Combo("B5_ESTMAT", cEstMat)
EndIf
oItem["UM"      ] := (cAlias)->UM
//-- Uma varredura só: a descrição dos órgãos e o indicador da coluna "Controlado?"
oItem["ORGAO"   ] := fDescOrg(aOrgaos, aListas, @cControl)
oItem["CONTROL" ] := cControl
xLimite := fCpoSB5(CPO_LIMEST, Nil)
If ValType(xLimite) == "N" .And. xLimite > 0
	oItem["LIMEST"  ] := xLimite
Else
	oItem["LIMEST"  ] := (cAlias)->EMAX
EndIf
oItem["FDS"     ] := fCpoSB5(CPO_FDS, CPO_VAZIO)
oItem["ARMAZEM" ] := cLocal
//-- [FORA DO LAYOUT] Condição de guarda (B5_XARMAZ), ver CPO_ARMAZ nos #DEFINE
// oItem["ARMAZEN" ] := fCpoSB5(CPO_ARMAZ, CPO_VAZIO)

If lLote
	oItem["LOTE"    ] := cLote
	oItem["FABRIC"  ] := fFabric(cProd, cLote, (cAlias)->ORIGLAN, (cAlias)->CLIFOR, (cAlias)->LOJA, oCache)
	oItem["DTFABRIC"] := (cAlias)->DTFABRIC
	oItem["DTVALID" ] := (cAlias)->DTVALID
	oItem["NFCOMPRA"] := fNFCompra(cAlias)
	//-- [FORA DO LAYOUT] Sub-lote, lote do fornecedor e NF em colunas separadas
	// oItem["SUBLOTE" ] := If(lSubLote, (cAlias)->SUBLOTE, "")
	// oItem["LOTEFOR" ] := (cAlias)->LOTEFOR
	// oItem["NFDOC"   ] := (cAlias)->DOC
	// oItem["NFSERIE" ] := (cAlias)->SERIE
	// oItem["NFEMIS"  ] := If(Empty((cAlias)->DOC), CtoD(""), ;
	//                      Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO"))
Else
	oItem["LOTE"    ] := ""
	oItem["FABRIC"  ] := ""
	oItem["DTFABRIC"] := CtoD("")
	oItem["DTVALID" ] := CtoD("")
	oItem["NFCOMPRA"] := ""
	//-- [FORA DO LAYOUT] Contrapartida das colunas acima para produto sem rastro
	// oItem["SUBLOTE" ] := ""
	// oItem["LOTEFOR" ] := ""
	// oItem["NFDOC"   ] := ""
	// oItem["NFSERIE" ] := ""
	// oItem["NFEMIS"  ] := CtoD("")
EndIf

oItem["SLDINI"  ] := nIni
oItem["COMPRAS" ] := aMov[1]
oItem["CONSUMO" ] := aMov[2]
oItem["PERDAS"  ] := aMov[3]
oItem["SLDFIM"  ] := nFim
oItem["RESP"    ] := ""
oItem["CONFER"  ] := ""
oItem["OBS"     ] := ""

//-- [FORA DO LAYOUT] Saldo do sistema e conferência. O nSis continua sendo calculado
//-- acima (serve para descartar item sem saldo e sem movimento), então para ter a
//-- checagem de volta basta reativar estas duas linhas e as colunas em ReportDef.
// oItem["SLDSIS"  ] := nSis
// oItem["CONFERE" ] := If(Abs(nFim - nSis) < 0.0001, "OK", "DIVERGENTE")

Return oItem

/*/{Protheus.doc} fImprime
Transfere os valores do item para as células e imprime a linha.
/*/
Static Function fImprime(oSecao, oItem)

//-- Mesma ordem das células em ReportDef.
//-- [FORA DO LAYOUT] Ao reativar uma coluna, acrescente o nome aqui na posição
//-- correspondente: "PRODUTO", "SUBLOTE", "LOTEFOR", "ARMAZEN", "NFDOC", "NFSERIE",
//-- "NFEMIS", "SLDSIS", "CONFERE".
Local aCelulas := {"LINHA", "FILIAL", "CONTROL", "ORGAO", "LIMEST", "CODMAPA", "NOMECOM", "NOMEQUI", ;
                   "CAS", "FORMA", "FABRIC", "LOTE", "FDS", "ARMAZEM", "DTFABRIC", "DTVALID", "UM", ;
                   "SLDINI", "COMPRAS", "NFCOMPRA", "CONSUMO", "PERDAS", "SLDFIM", "RESP", "CONFER", "OBS"}
Local nI       := 0

For nI := 1 To Len(aCelulas)
	oSecao:Cell(aCelulas[nI]):SetValue(oItem[aCelulas[nI]])
Next nI

oSecao:PrintLine()

Return

/*/{Protheus.doc} fNFCompra
Nota fiscal de entrada do lote num único texto: "numero/serie - fornecedor - emissao".
Cada parte só entra quando tem conteúdo, para não deixar separadores soltos.
@type  Static Function
@author bacoetrom@gmail.com
@since  06/11/2026
@param cAlias, character, alias da consulta posicionada no lote (SB8)
@return character, nota fiscal de compra formatada
/*/
Static Function fNFCompra(cAlias)

Local cDoc   := AllTrim((cAlias)->DOC)
Local cSerie := AllTrim((cAlias)->SERIE)
Local cForn  := ""
Local dEmis  := CtoD("")
Local cRet   := ""

If !Empty(cDoc)
	cRet := cDoc
	If !Empty(cSerie)
		cRet += "/" + cSerie
	EndIf

	If !Empty((cAlias)->CLIFOR)
		cForn := fNomeSA2((cAlias)->CLIFOR + (cAlias)->LOJA)
		If !Empty(cForn)
			cRet += " - " + cForn
		EndIf
	EndIf

	dEmis := Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + ;
	                   (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO")
	If !Empty(dEmis)
		cRet += " - " + DtoC(dEmis)
	EndIf
EndIf

Return cRet

/*/{Protheus.doc} fFabric
Fabricante do lote via amarração Produto x Fornecedor (SA5) - MIT041, seção 5.
  CP: fornecedor do lote (B8_CLIFOR/B8_LOJA) | TR: fornecedor do lote de origem | PR: própria empresa.
  A5_FABR preenchido -> fabricante; vazio e A5_FABREV F/vazio -> o próprio fornecedor;
  R/P sem fabricante -> fornecedor sinalizado; mais de um fabricante -> primeiro, sinalizado.
/*/
Static Function fFabric(cProd, cLote, cOrigLan, cCliFor, cLoja, oCache)

Local aArea   := GetArea()
Local aAreaA5 := SA5->(GetArea())
Local aFab    := {}
Local cRet    := ""
Local cChave  := ""
Local cFabRev := ""
Local cSeek   := ""

If AllTrim(cOrigLan) == "PR"
	cRet := fNomeEmp()
Else
	If AllTrim(cOrigLan) == "TR" .Or. Empty(cCliFor)
		fLoteOrig(cProd, cLote, @cCliFor, @cLoja)
	EndIf

	If !Empty(cCliFor)
		cChave := cProd + cCliFor + cLoja
		If ValType(oCache[cChave]) == "C"
			cRet := oCache[cChave]
		Else
			cSeek := xFilial("SA5") + cCliFor + cLoja + cProd
			SA5->(DbSetOrder(1))   //-- A5_FILIAL+A5_FORNECE+A5_LOJA+A5_PRODUTO+...
			If SA5->(MsSeek(cSeek))
				While !SA5->(Eof()) .And. SA5->(A5_FILIAL + A5_FORNECE + A5_LOJA + A5_PRODUTO) == cSeek
					If !Empty(SA5->A5_FABR) .And. aScan(aFab, SA5->A5_FABR + SA5->A5_FALOJA) == 0
						aAdd(aFab, SA5->A5_FABR + SA5->A5_FALOJA)
					EndIf
					If Empty(cFabRev)
						cFabRev := SA5->A5_FABREV
					EndIf
					SA5->(DbSkip())
				EndDo
			EndIf

			Do Case
			Case Len(aFab) == 1
				cRet := fNomeSA2(aFab[1])
			Case Len(aFab) > 1
				cRet := fNomeSA2(aFab[1]) + " (+" + cValToChar(Len(aFab) - 1) + " FABRIC. NA SA5)"
			Case !Empty(cFabRev) .And. cFabRev $ "RP"
				cRet := fNomeSA2(cCliFor + cLoja) + " (REVENDEDOR - FABRICANTE NAO INFORMADO)"
			OtherWise
				cRet := fNomeSA2(cCliFor + cLoja)
			EndCase

			oCache[cChave] := cRet
		EndIf
	EndIf
EndIf

RestArea(aAreaA5)
RestArea(aArea)

Return cRet

/*/{Protheus.doc} fLoteOrig
Lote recebido por transferência: busca o fornecedor no lote de origem (compra),
em qualquer filial.
/*/
Static Function fLoteOrig(cProd, cLote, cCliFor, cLoja)

Local cAlias := GetNextAlias()
Local cQry   := ""

cQry := "SELECT B8_CLIFOR, B8_LOJA FROM " + RetSqlName("SB8") + " "
cQry += " WHERE B8_PRODUTO = '" + cProd + "' AND B8_LOTECTL = '" + cLote + "' "
cQry += "   AND B8_ORIGLAN = 'CP' AND B8_CLIFOR <> ' ' AND D_E_L_E_T_ = ' ' "
cQry += " ORDER BY B8_DATA "

DbUseArea(.T., "TOPCONN", TcGenQry(, , ChangeQuery(cQry)), cAlias, .F., .T.)
If !(cAlias)->(Eof())
	cCliFor := (cAlias)->B8_CLIFOR
	cLoja   := (cAlias)->B8_LOJA
EndIf
(cAlias)->(DbCloseArea())

Return

/*/{Protheus.doc} fOrgaos
Grupo da pergunta MV_PAR11 - órgãos fiscalizadores: código, descrição, campo na SB5,
parâmetro de origem e regra (flag = 'S').
A ANVISA não entra aqui: marcar qualquer opção da pergunta MV_PAR12 já significa
produto controlado pela ANVISA.
/*/
Static Function fOrgaos()

Local aOrgaos := {}

aAdd(aOrgaos, {"PC", "POLÍCIA CIVIL"  , fCampoMV("MV_MTR947A")      , "MV_MTR947A", .F., "", "SB5"})
aAdd(aOrgaos, {"PF", "POLÍCIA FEDERAL", fCampoMV("MV_PRODPF")       , "MV_PRODPF" , .F., "", "SB5"})
aAdd(aOrgaos, {"EX", "EXÉRCITO"       , fCampoMV("MV_MTR949A")      , "MV_MTR949A", .F., "", "SB5"})
//-- [FORA DO LAYOUT] Opção ANVISA pela flag B5_XANVISA (ver CPO_ANVISA nos #DEFINE).
//-- Saiu porque a ANVISA ganhou pergunta própria (MV_PAR12, listas da 344/98). Reativar
//-- aqui faria a flag voltar ao filtro de órgãos e às colunas "Órgão Fiscalizador" e
//-- "Controlado", convivendo com as listas.
// aAdd(aOrgaos, {"AV", "ANVISA"         , fCampoSB5(CPO_ANVISA, .T.)  , ""          , .T., "", "SB5"})

Return aOrgaos

/*/{Protheus.doc} fListas
Grupo da pergunta MV_PAR12 - listas da Portaria SVS/MS 344/98, na mesma estrutura dos
órgãos. Todas apontam para o único campo da lista (fCampoLis, SB1.B1_TPPROD) e se
diferenciam pelo conteúdo esperado (ORG_CONTEU), que é o próprio código da lista.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, grupo de opções das listas da ANVISA
/*/
Static Function fListas()

Local aListas := {}
Local aAnv    := fListAnv()
Local cCpoLis := fCampoLis()
Local nI      := 0

For nI := 1 To Len(aAnv)
	aAdd(aListas, {aAnv[nI][1], aAnv[nI][2], cCpoLis, PAR_LISTA, .F., aAnv[nI][1], TAB_LISTA})
Next nI

FwFreeArray(aAnv)

Return aListas

/*/{Protheus.doc} fListAnv
Listas de substâncias sujeitas a controle especial da Portaria SVS/MS 344/98, lidas da
tabela genérica SX5_LISTA da SX5 - a mesma que alimenta o campo B1_TPPROD. Assim, lista
nova ou descrição alterada no cadastro do cliente aparece sem recompilar o fonte.

Se a tabela genérica não estiver cadastrada, cai na relação fixa (fListFix): sem opções
o f_Opcoes não teria o que exibir e a pergunta ficaria inutilizável.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, pares {código de 2 posições, descrição}
/*/
Static Function fListAnv()

Local aListas := {}
Local aSX5    := FWGetSX5(SX5_LISTA)
Local cChave  := ""
Local nI      := 0

If ValType(aSX5) <> "A"
	aSX5 := {}
EndIf

For nI := 1 To Len(aSX5)
	cChave := AllTrim(aSX5[nI][3])   //-- [3] X5_CHAVE, [4] X5_DESCRI
	//-- Os códigos entram numa string de largura fixa: chave de tamanho diferente
	//-- quebraria o alinhamento, e NC é reservado para a opção "não controlado"
	If Len(cChave) == ORG_TAM .And. cChave <> ORG_NC
		aAdd(aListas, {cChave, AllTrim(aSX5[nI][4])})
	EndIf
Next nI

FwFreeArray(aSX5)

If Empty(aListas)
	aListas := fListFix()
EndIf

Return aListas

/*/{Protheus.doc} fListFix
Relação fixa das listas da Portaria SVS/MS 344/98 (Anexo I), usada apenas quando a
tabela genérica SX5_LISTA não está cadastrada.
A3 e B1 compartilham a descrição "PSICOTRÓPICOS" por definição da própria Portaria;
o código exibido ao lado da descrição diferencia as duas opções.
@type Function
@author Pablo Regis
@since  05/11/2026
@return array, pares {código de 2 posições, descrição}
/*/
Static Function fListFix()

Local aListas := {}

aAdd(aListas, {"A1", "ANVISA - ENTORPECENTES"})
aAdd(aListas, {"A2", "ANVISA - ENTORPECENTES DE USO EM CONCENTRAÇÕES ESPECIAIS"})
aAdd(aListas, {"A3", "ANVISA - PSICOTRÓPICOS"})
aAdd(aListas, {"B1", "ANVISA - PSICOTRÓPICOS"})
aAdd(aListas, {"B2", "ANVISA - PSICOTRÓPICOS ANOREXÍGENOS"})
aAdd(aListas, {"C1", "ANVISA - OUTRAS SUBSTÂNCIAS SUJEITAS A CONTROLE ESPECIAL"})
aAdd(aListas, {"C2", "ANVISA - SUBSTÂNCIAS RETINÓICAS"})
aAdd(aListas, {"C3", "ANVISA - IMUNOSSUPRESSORES"})
aAdd(aListas, {"C4", "ANVISA - ANTIRRETROVIRAIS"})
aAdd(aListas, {"C5", "ANVISA - SUBSTÂNCIAS ANABOLIZANTES"})
aAdd(aListas, {"D1", "ANVISA - PRECURSORAS"})
aAdd(aListas, {"D2", "ANVISA - REAGENTES QUÍMICOS"})

Return aListas

/*/{Protheus.doc} fCampoLis
Nome do campo que guarda a lista da Portaria 344/98. Usa o parâmetro PAR_LISTA quando
configurado e, na ausência dele, o campo padrão CPO_LISTA (B1_TPPROD, na SB1).
Retorna vazio se o campo não existir (as listas saem do filtro).
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, nome do campo ou vazio
/*/
Static Function fCampoLis()

Local cCampo := Upper(AllTrim(SuperGetMV(PAR_LISTA, .F., CPO_LISTA)))

cCampo := StrTran(cCampo, TAB_LISTA + "->", "")

Return fCampoTab(cCampo, TAB_LISTA, .T.)

/*/{Protheus.doc} fCondOrg
Condição SQL do órgão: produto controlado (lControla = .T.) ou não controlado (.F.) por ele.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrg, array, item do array de órgãos (fOrgaos)
@param lControla, logical, .T. condição positiva; .F. condição negada
@return character, condição SQL
/*/
Static Function fCondOrg(aOrg, lControla)

//-- As duas queries do fProcFil usam SB5 e SB1 com esses mesmos apelidos
Local cCampo := "COALESCE(" + aOrg[ORG_ALIAS] + "." + aOrg[ORG_CAMPO] + ",' ')"
Local cRet   := ""

Do Case
Case !Empty(aOrg[ORG_CONTEU])
	//-- Lista da 344/98: o campo guarda o código da lista
	If lControla
		cRet := cCampo + " = '" + aOrg[ORG_CONTEU] + "'"
	Else
		cRet := cCampo + " <> '" + aOrg[ORG_CONTEU] + "'"
	EndIf
Case aOrg[ORG_PREENCH]
	If lControla
		cRet := cCampo + " <> ' '"
	Else
		cRet := cCampo + " = ' '"
	EndIf
OtherWise
	If lControla
		cRet := cCampo + " = 'S'"
	Else
		cRet := cCampo + " <> 'S'"
	EndIf
EndCase

Return cRet

/*/{Protheus.doc} fDescOrg
Órgãos e listas que controlam o produto posicionado na SB5 (flag = 'S', campo
preenchido ou conteúdo igual ao código da lista da 344/98).

Devolve também, por referência, o indicador da coluna "Controlado?": SIM quando ao
menos um órgão/lista se aplica, NÃO quando nenhum se aplica e CPO_VAZIO quando não
existe nenhum campo na SB5 - nesse caso o produto não é "não controlado", é um
produto que o relatório não tem como classificar, e afirmar NÃO seria incorreto num
relatório regulatório.
@type Function
@author Pablo Regis
@since  21/10/2026
@param aOrgaos, array, grupo dos órgãos fiscalizadores (fOrgaos)
@param aListas, array, grupo das listas da ANVISA (fListas)
@param cControl, character, retorna SIM, NÃO ou CPO_VAZIO (por referência)
@return character, códigos aplicáveis separados por " / "
/*/
Static Function fDescOrg(aOrgaos, aListas, cControl)

Local aDesc  := {}
Local cRet   := ""
Local lCampo := .F.

fMarcGrp(aOrgaos, @aDesc, @lCampo)
fMarcGrp(aListas, @aDesc, @lCampo)

Do Case
Case !lCampo
	//-- Sem campo de órgão nem de lista na SB5: não há como classificar o produto
	cRet     := CPO_VAZIO
	cControl := CPO_VAZIO
Case Empty(aDesc)
	cRet     := "NAO CONTROLADO"
	cControl := "NÃO"
OtherWise
	cRet     := fJunta(aDesc, " / ")
	cControl := "SIM"
EndCase

FwFreeArray(aDesc)

Return cRet

/*/{Protheus.doc} fMarcGrp
Acrescenta em aDesc os códigos do grupo que se aplicam ao produto posicionado na SB5
e sinaliza em lCampo se o grupo tem ao menos um campo existente.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param aDesc, array, acumula os códigos aplicáveis (por referência)
@param lCampo, logical, .T. se algum campo do grupo existe na SB5 (por referência)
@return nil
/*/
Static Function fMarcGrp(aGrupo, aDesc, lCampo)

Local cConteudo := ""
Local nI        := 0
Local lControla := .F.

For nI := 1 To Len(aGrupo)
	If !Empty(aGrupo[nI][ORG_CAMPO])
		lCampo    := .T.
		cConteudo := fCpoTab(aGrupo[nI][ORG_CAMPO], aGrupo[nI][ORG_ALIAS], "")
		Do Case
		Case !Empty(aGrupo[nI][ORG_CONTEU])
			lControla := cConteudo == aGrupo[nI][ORG_CONTEU]
		Case aGrupo[nI][ORG_PREENCH]
			lControla := !Empty(cConteudo)
		OtherWise
			lControla := cConteudo == "S"
		EndCase
		If lControla
			aAdd(aDesc, aGrupo[nI][ORG_COD])
		EndIf
	EndIf
Next nI

Return

/*/{Protheus.doc} fConfig
Campos opcionais da configuração PF (nome comercial e código SIPROQUIM).
/*/
Static Function fConfig()

Local oCfg := JsonObject():New()

oCfg["DESCPR" ] := fCampoMV("MV_DESCPR")
oCfg["CODMAPA"] := fCampoMV("MV_CODMAPA")

Return oCfg

/*/{Protheus.doc} fCampoMV
Nome do campo da SB5 informado no parâmetro; vazio se o parâmetro estiver vazio
ou o campo não existir.
/*/
Static Function fCampoMV(cParam)

Local cCampo := Upper(AllTrim(SuperGetMV(cParam, .F., "")))

cCampo := StrTran(cCampo, "SB5->", "")

Return fCampoSB5(cCampo, .T.)

/*/{Protheus.doc} fCampoSB5
Retorna o nome do campo se existir na SB5 (lValida) ou vazio.

A validação roda antes do oSecao:Init() (que é quem abre as tabelas da seção), por
isso a SB5 é aberta aqui com ChkFile() quando necessário: sem a tabela aberta o
FieldPos() daria 0 e todos os campos de órgão seriam tratados como inexistentes.
@type Function
@author Pablo Regis
@since  21/10/2026
@param cCampo, character, nome do campo
@param lValida, logical, .F. devolve vazio sem consultar a SB5
@return character, nome do campo ou vazio
/*/
Static Function fCampoSB5(cCampo, lValida)
Return fCampoTab(cCampo, "SB5", lValida)

/*/{Protheus.doc} fCampoTab
Retorna o nome do campo se existir na tabela informada (lValida) ou vazio. Os campos
dos órgãos ficam na SB5 e a lista da 344/98 na SB1, por isso a tabela é parâmetro.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCampo, character, nome do campo
@param cAlias, character, alias da tabela ("SB5" ou "SB1")
@param lValida, logical, .F. devolve vazio sem consultar a tabela
@return character, nome do campo ou vazio
/*/
Static Function fCampoTab(cCampo, cAlias, lValida)

Local aArea := GetArea()

Do Case
Case !lValida .Or. Empty(cCampo) .Or. Empty(cAlias)
	cCampo := ""
Case Select(cAlias) == 0 .And. !ChkFile(cAlias)
	//-- Tabela indisponível no ambiente: não há como validar o campo
	cCampo := ""
Case (cAlias)->(FieldPos(cCampo)) == 0
	cCampo := ""
EndCase

RestArea(aArea)

Return cCampo

/*/{Protheus.doc} fCpoSB5
Conteúdo de um campo da SB5 posicionada; xDefault se o campo não existir.
/*/
Static Function fCpoSB5(cCampo, xDefault)
Return fCpoTab(cCampo, "SB5", xDefault)

/*/{Protheus.doc} fCpoTab
Conteúdo de um campo da tabela posicionada; xDefault se o campo não existir ou a
tabela não estiver posicionada.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCampo, character, nome do campo
@param cAlias, character, alias da tabela ("SB5" ou "SB1")
@param xDefault, variant, conteúdo devolvido quando o campo não existe
@return variant, conteúdo do campo
/*/
Static Function fCpoTab(cCampo, cAlias, xDefault)

Local xRet := xDefault
Local nPos := 0

If !Empty(cCampo) .And. !Empty(cAlias) .And. Select(cAlias) > 0
	nPos := (cAlias)->(FieldPos(cCampo))
	If nPos > 0 .And. !(cAlias)->(Eof())
		xRet := (cAlias)->(FieldGet(nPos))
		If ValType(xRet) == "C"
			xRet := AllTrim(xRet)
		EndIf
	EndIf
EndIf

Return xRet

/*/{Protheus.doc} fNomeSA2
Nome do fornecedor/fabricante (código + loja).
/*/
Static Function fNomeSA2(cCodLoja)
Return AllTrim(Posicione("SA2", 1, xFilial("SA2") + cCodLoja, "A2_NOME"))

/*/{Protheus.doc} fNomeEmp
Razão social da filial corrente (lote de produção própria).
/*/
Static Function fNomeEmp()

Local aAreaSM0 := SM0->(GetArea())
Local cNome    := ""

If SM0->(DbSeek(cEmpAnt + cFilAnt))
	cNome := AllTrim(SM0->M0_NOMECOM)
EndIf
RestArea(aAreaSM0)

Return cNome

/*/{Protheus.doc} fChave
Chave do item: Produto | Armazém | Lote | Sub-Lote.
/*/
Static Function fChave(cProd, cLocal, cLote, cSubLote)
Return AllTrim(cProd) + "|" + AllTrim(cLocal) + "|" + AllTrim(cLote) + "|" + AllTrim(cSubLote)

/*/{Protheus.doc} fSqlIn
"A/B/C" -> "'A','B','C'" para cláusula IN.
/*/
Static Function fSqlIn(cLista)

Local aItens := StrTokArr(cLista, "/")
Local cRet   := ""
Local nI     := 0

For nI := 1 To Len(aItens)
	cRet += If(nI > 1, ",", "") + "'" + AllTrim(aItens[nI]) + "'"
Next nI

Return If(Empty(cRet), "'###'", cRet)

/*/{Protheus.doc} fJunta
Concatena os elementos do array com o separador.
/*/
Static Function fJunta(aItens, cSep)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aItens)
	cRet += If(nI > 1, cSep, "") + aItens[nI]
Next nI

Return cRet

/*/{Protheus.doc} fSelGrp
Códigos marcados na pergunta de um grupo, concatenados e sem as posições não marcadas
(ex.: "PF**EX****" -> "PFEX"). Conteúdo inválido digitado na pergunta é descartado.
@type Function
@author Pablo Regis
@since  21/10/2026
@param nParam, numeric, número da pergunta (PAR_ORG ou PAR_LIS)
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@return character, códigos selecionados
/*/
Static Function fSelGrp(nParam, aGrupo)

Local aOpcoes  := {}
Local cCodigos := ""
Local cVar     := "mv_par" + StrZero(nParam, 2)
Local cPar     := ""
Local cCod     := ""
Local cRet     := ""
Local nI       := 0

If Type(cVar) == "C"
	cPar := &(cVar)
EndIf

aOpcoes := fOpcGrp(aGrupo, @cCodigos)

For nI := 1 To Len(cPar) Step ORG_TAM
	cCod := SubStr(cPar, nI, ORG_TAM)
	If fOrgPos(cCod, cCodigos) > 0
		cRet += cCod
	EndIf
Next nI

FwFreeArray(aOpcoes)

Return cRet

/*/{Protheus.doc} fOpcGrp
Opções de um grupo para o f_Opcoes, no formato "XX - DESCRIÇÃO" exigido pela função
(código com ORG_TAM posições seguido de " - "). NC é sempre a última opção: não é um
órgão nem uma lista, serve para trazer os produtos fora do grupo.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param cCodigos, character, retorna a concatenação dos códigos na ordem das opções (por referência)
@param cDescNC, character, descrição da opção NC; o padrão serve para quem só precisa dos códigos
@return array, opções exibidas na tela do f_Opcoes
/*/
Static Function fOpcGrp(aGrupo, cCodigos, cDescNC)

Local aOpcoes := {}
Local nI      := 0

Default cDescNC := "NÃO CONTROLADO"

cCodigos := ""

For nI := 1 To Len(aGrupo)
	aAdd(aOpcoes, aGrupo[nI][ORG_COD] + " - " + aGrupo[nI][ORG_DESC])
	cCodigos += aGrupo[nI][ORG_COD]
Next nI

aAdd(aOpcoes, ORG_NC + " - " + cDescNC)
cCodigos += ORG_NC

Return aOpcoes

/*/{Protheus.doc} fDefGrp
Conteúdo inicial da pergunta de um grupo: todas as opções do grupo marcadas, com NC
marcado ou não conforme lNC.
@type Function
@author Pablo Regis
@since  05/11/2026
@param aGrupo, array, grupo de opções (fOrgaos ou fListas)
@param lNC, logical, .T. marca também a opção "não controlado"
@return character, conteúdo inicial da pergunta
/*/
Static Function fDefGrp(aGrupo, lNC)

Local cRet := ""
Local nI   := 0

For nI := 1 To Len(aGrupo)
	cRet += aGrupo[nI][ORG_COD]
Next nI

If lNC
	cRet += ORG_NC
Else
	cRet += Replicate("*", ORG_TAM)
EndIf

Return cRet

/*/{Protheus.doc} fOrgDef
Conteúdo inicial da pergunta MV_PAR11: os 4 órgãos marcados e NC desmarcado, ou seja,
só produtos controlados por algum órgão - o comportamento histórico do relatório.
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, conteúdo inicial da pergunta
/*/
Static Function fOrgDef()

Local aGrupo := fOrgaos()
Local cRet   := fDefGrp(aGrupo, .F.)

FwFreeArray(aGrupo)

Return cRet

/*/{Protheus.doc} fLisDef
Conteúdo inicial da pergunta MV_PAR12: todas as listas e NC marcados. Assim o
parâmetro nasce sem restringir nada e o recorte por lista é uma escolha explícita do
usuário - inclusive quando o campo da lista não existir no dicionário.
@type Function
@author Pablo Regis
@since  05/11/2026
@return character, conteúdo inicial da pergunta
/*/
Static Function fLisDef()

Local aGrupo := fListas()
Local cRet   := fDefGrp(aGrupo, .T.)

FwFreeArray(aGrupo)

Return cRet

/*/{Protheus.doc} fOrgPos
Posição do código na lista de códigos válidos, comparando em blocos de ORG_TAM
posições. Retorna 0 para as posições não marcadas ("**") e para códigos inexistentes.
@type Function
@author Pablo Regis
@since  05/11/2026
@param cCod, character, código a localizar
@param cCodigos, character, concatenação dos códigos válidos (fOpcGrp)
@return numeric, posição do código (1..n) ou 0
/*/
Static Function fOrgPos(cCod, cCodigos)

Local nRet := 0
Local nI   := 0

For nI := 1 To Len(cCodigos) Step ORG_TAM
	If SubStr(cCodigos, nI, ORG_TAM) == cCod
		nRet := ((nI - 1) / ORG_TAM) + 1
		Exit
	EndIf
Next nI

Return nRet

