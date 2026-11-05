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
  MV_PAR11 Órgãos Fiscalizadores    C  seleção múltipla via f_Opcoes (tela "Escolha Padrões"):
           Polícia Civil, Polícia Federal, Exército, ANVISA, as 12 listas da Portaria
           SVS/MS 344/98 (A1, A2, A3, B1, B2, C1 a C5, D1, D2) e Não Controlado. O conteúdo
           é a concatenação dos códigos de 2 posições, com "**" nas opções não marcadas
           (ex.: "PF**EX" + Replicate("*", 28) = Polícia Federal + Exército)
           Padrão: os 4 órgãos marcados; listas e "não controlado" desmarcados

Flags de produto controlado na SB5 (configuração padrão TOTVS dos mapas):
  MV_PRODPF  -> campo da Polícia Federal  (ex.: B5_PRODPF)   - MATA950/MATR913
  MV_MTR949A -> campo do Exército         (ex.: B5_PRODEX)   - MATR949
  MV_MTR947A -> campo da Polícia Civil    (ex.: B5_PRODCON)  - MATR947
Opcionais (configuração PF): MV_DESCPR (nome comercial), MV_CODMAPA (cód. SIPROQUIM).

Campos customizados (SB5): B5_XCAS, B5_XFDS, B5_XANVISA, B5_XARMAZ, B5_XLIMEST e
B5_XLISTA (lista da Portaria SVS/MS 344/98, C 2: "A1".."D2").
Todos são opcionais: campo inexistente na SB5 é impresso como "   ". No filtro, a
opção cujo campo não existe é ignorada e registrada no diagnóstico - o resultado
fica mais restrito, nunca mais abrangente. Mas se NENHUMA opção marcada tiver campo
na SB5, a emissão é bloqueada: sem condição de órgão o relatório listaria todo o
estoque como se fosse controlado.

@type  User Function
@author bacoetrom@gmail.com
@since  08/10/2026
@version 1.0
/*/

//-- Campos customizados (MIT041 - seção 7.2)
#DEFINE CPO_CAS      "B5_XCAS"
#DEFINE CPO_FDS      "B5_XFDS"
#DEFINE CPO_ANVISA   "B5_XANVISA"
#DEFINE CPO_ARMAZ    "B5_XARMAZ"
#DEFINE CPO_LIMEST   "B5_XLIMEST"

//-- Lista da Portaria SVS/MS 344/98 do produto (C 2: "A1".."D2"). O nome do campo pode
//-- ser trocado pelo parâmetro PAR_LISTA, como nos demais órgãos
#DEFINE CPO_LISTA    "B5_XLISTA"
#DEFINE PAR_LISTA    "MV_XLISANV"

//-- Conteúdo impresso quando o campo não existe na SB5
#DEFINE CPO_VAZIO    "   "

//-- Regras de classificação (MIT041 - seção 6). PERDAS: pendência P1 com o cliente
#DEFINE CF_TRF_ENT   "1151/1152/1552/2151/2152/2552"
#DEFINE CF_TRF_SAI   "5151/5152/5156/5552/6151/6152/6156/6552"
#DEFINE D3_CF_TRANSF "RE4/DE4/RE7/DE7"
#DEFINE TM_PERDAS    "499/999"

//-- Órgãos fiscalizadores: seleção múltipla (f_Opcoes) na pergunta MV_PAR11
#DEFINE ORG_TAM      2      //-- posições do código de cada órgão
#DEFINE ORG_NC       "NC"   //-- "não controlado": opção de filtro, não é um órgão
#DEFINE PAR_ORG      11
#DEFINE QTD_PARAM    11
#DEFINE MAX_DIAS     4095
#DEFINE NUM_PERG     "CI04R01"

//-- Posições do array de órgãos
#DEFINE ORG_COD      1
#DEFINE ORG_DESC     2
#DEFINE ORG_CAMPO    3
#DEFINE ORG_PARAM    4
#DEFINE ORG_PREENCH  5   //-- .T.: controlado quando o campo está preenchido (ex.: registro ANVISA); .F.: flag = 'S'
#DEFINE ORG_CONTEU   6   //-- preenchido: controlado quando o campo tem este conteúdo (listas da 344/98).
                         //-- Também identifica a opção como sublista, que não vem marcada por padrão

/*/{Protheus.doc} CI04R01
Ponto de entrada do relatório.
/*/
User Function CI04R01()

Local oReport

Private mv_par01, mv_par02, mv_par03, mv_par04, mv_par05, mv_par06, mv_par07, mv_par08
Private mv_par09, mv_par10, mv_par11

If !fParams()
	Return
EndIf

oReport := ReportDef()
oReport:PrintDialog()

Return

/*/{Protheus.doc} fParams
Tela de parâmetros (ParamBox). Também acionada pelo botão "Parâmetros" do TReport.
@type  Static Function
@author bacoetrom@gmail.com
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
//-- Seleção múltipla pelo f_Opcoes: a validação da pergunta abre a tela de opções
aAdd(aPergs, {1, "Órgãos Fiscalizadores", fOrgDef(), "@!", "U_CI04ORG()", "", "", 100, .T.})

If ParamBox(aPergs, "Parâmetros - Reagentes Controlados", @aRet, , , .T., , , , NUM_PERG, .T., .T.)
	For nI := 1 To QTD_PARAM
		&("mv_par" + StrZero(nI, 2)) := aRet[nI]
	Next nI
	lRet := .T.
EndIf

FwFreeArray(aPergs)

Return lRet

/*/{Protheus.doc} CI04ORG
Validação da pergunta MV_PAR11: abre a seleção múltipla dos órgãos fiscalizadores
com o f_Opcoes (tela padrão "Escolha Padrões") e grava os códigos marcados na
pergunta.

O ParamBox macro-executa o conteúdo da validação, por isso esta rotina precisa ser
User Function (uma Static Function não é visível para o compilador de macros). O
ParamBox informa o nome da variável da pergunta ao TGet (cReadVar), de modo que
ReadVar() devolve "MV_PAR11" durante a validação.

@type  User Function
@author bacoetrom@gmail.com
@since  05/11/2026
@return logical, .T. se ao menos um órgão ficou marcado
/*/
User Function CI04ORG()

Local aOpcoes  := {}
Local cCodigos := ""
Local cVar     := AllTrim(ReadVar())
Local cSel     := ""
Local lRet     := .F.

//-- Fora do contexto do get (ReadVar vazio) a pergunta é endereçada pelo nome
If Empty(cVar)
	cVar := "MV_PAR" + StrZero(PAR_ORG, 2)
EndIf

aOpcoes := fOrgOpc(@cCodigos)

//-- Conteúdo atual: o f_Opcoes marca as opções já presentes na variável
If Type(cVar) == "C"
	cSel := &(cVar)
EndIf

If f_Opcoes(@cSel, "Órgãos Fiscalizadores", aOpcoes, cCodigos, , , .F., ORG_TAM, Len(aOpcoes))
	&(cVar) := cSel
EndIf

lRet := !Empty(fOrgSel())

If !lRet
	Help(NIL, NIL, NUM_PERG, NIL, "Selecione ao menos um órgão fiscalizador.", 1, 0, NIL, NIL, NIL, NIL, NIL, ;
	     {"Marque uma das opções na tela de seleção."})
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
TRCell():New(oSecao, "FILIAL"  , "", "Filial"          + "/" + "Branch"         , "@!", FWSizeFilial())
TRCell():New(oSecao, "PRODUTO" , "", "Código"          + "/" + "Code"           , "@!", TamSX3("B1_COD")[1])
TRCell():New(oSecao, "NOMECOM" , "", "Nome Comercial"  + "/" + "Trade Name"     , "@!", 30)
TRCell():New(oSecao, "NOMEQUI" , "", "Nome Químico"    + "/" + "Chemical Name"  , "@!", 30)
TRCell():New(oSecao, "CAS"     , "", "Nº CAS"          + "/" + "CAS Number"     , "@!", 12)
TRCell():New(oSecao, "CODMAPA" , "", "Cód. SIPROQUIM"  + "/" + "SIPROQUIM Code" , "@!", 11)
TRCell():New(oSecao, "FORMA"   , "", "Forma"           + "/" + "Physical Form"  , "@!", 10)
TRCell():New(oSecao, "UM"      , "", "UM"              + "/" + "UoM"            , "@!", TamSX3("B1_UM")[1])

//-- Regulatório
TRCell():New(oSecao, "ORGAO"   , "", "Órgão Fiscaliz." + "/" + "Regulatory Agency", "@!", 30)
TRCell():New(oSecao, "LIMEST"  , "", "Limite Estoque"  + "/" + "Stock Limit"    , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "FDS"     , "", "FDS"             + "/" + "SDS"            , "@!", 20)
TRCell():New(oSecao, "ARMAZEN" , "", "Armazenamento"   + "/" + "Storage"        , "@!", 20)

//-- Lote
TRCell():New(oSecao, "ARMAZEM" , "", "Armazém"         + "/" + "Warehouse"      , "@!", TamSX3("B8_LOCAL")[1])
TRCell():New(oSecao, "LOTE"    , "", "Lote"            + "/" + "Batch"          , "@!", TamSX3("B8_LOTECTL")[1])
TRCell():New(oSecao, "SUBLOTE" , "", "Sub-Lote"        + "/" + "Sub-Batch"      , "@!", TamSX3("B8_NUMLOTE")[1])
TRCell():New(oSecao, "LOTEFOR" , "", "Lote Fabric."    + "/" + "Mfr. Batch"     , "@!", TamSX3("B8_LOTEFOR")[1])
TRCell():New(oSecao, "FABRIC"  , "", "Fabricante"      + "/" + "Manufacturer"   , "@!", 30)
TRCell():New(oSecao, "DTFABRIC", "", "Dt. Fabricação"  + "/" + "Mfg. Date"      , "@D", 10)
TRCell():New(oSecao, "DTVALID" , "", "Dt. Validade"    + "/" + "Expiry Date"    , "@D", 10)

//-- Nota fiscal de compra
TRCell():New(oSecao, "NFDOC"   , "", "NF Compra"       + "/" + "Purchase Inv."  , "@!", TamSX3("B8_DOC")[1])
TRCell():New(oSecao, "NFSERIE" , "", "Série"           + "/" + "Series"         , "@!", TamSX3("B8_SERIE")[1])
TRCell():New(oSecao, "NFEMIS"  , "", "Emissão NF"      + "/" + "Inv. Date"      , "@D", 10)

//-- Balanço do período
TRCell():New(oSecao, "SLDINI"  , "", "Saldo Inicial"   + "/" + "Opening Balance", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "COMPRAS" , "", "Compras"         + "/" + "Purchases"      , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "CONSUMO" , "", "Consumo"         + "/" + "Consumption"    , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "PERDAS"  , "", "Perdas/Transf."  + "/" + "Losses/Transfers", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDFIM"  , "", "Saldo Final"     + "/" + "Closing Balance", cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "SLDSIS"  , "", "Saldo Sistema"   + "/" + "System Balance" , cPictQtd, nTamQtd, , , "RIGHT", , "RIGHT")
TRCell():New(oSecao, "CONFERE" , "", "Conferência"     + "/" + "Check"          , "@!", 10)

//-- Responsabilidade (preenchimento manual)
TRCell():New(oSecao, "RESP"    , "", "Responsável"     + "/" + "Responsible"    , "@!", 15)
TRCell():New(oSecao, "CONFER"  , "", "Conferente"      + "/" + "Checked by"     , "@!", 15)
TRCell():New(oSecao, "OBS"     , "", "Observações"     + "/" + "Remarks"        , "@!", 20)

//-- Totais por produto (unidades diferentes entre produtos: sem total geral)
oBreak := TRBreak():New(oSecao, oSecao:Cell("PRODUTO"), "Total do produto / Product total", .F.)
TRFunction():New(oSecao:Cell("SLDINI" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("COMPRAS"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("CONSUMO"), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("PERDAS" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)
TRFunction():New(oSecao:Cell("SLDFIM" ), , "SUM", oBreak, , cPictQtd, , .F., .F.)

Return oReport

/*/{Protheus.doc} ReportPrint
Valida os filtros, percorre as filiais do intervalo e imprime.
/*/
Static Function ReportPrint(oReport)

Local oSecao   := oReport:Section(1)
Local aSM0     := {}
Local aFiliais := {}
Local aOrgaos  := {}
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

If !fValida(aOrgaos, @cCondOrg, @cErro, @cIgnora)
	Help(NIL, NIL, NUM_PERG, NIL, cErro, 1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros do relatório."})
	oReport:CancelPrint()
	Return
EndIf

//-- Órgãos sem campo na SB5 ficam fora do filtro (apenas registrado no diagnóstico)
If Empty(cIgnora)
	oDiag["ORGIGN"] := "nenhum"
Else
	oDiag["ORGIGN"] := cIgnora
EndIf

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
	fProcFil(oReport, oSecao, aOrgaos, cCondOrg, oCfg, oDiag)
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
	     "Órgãos fora do filtro (campo inexistente na SB5): " + oDiag["ORGIGN"] + CRLF + ;
	     "Filtro de órgãos: " + cCondOrg, ;
	     1, 0, NIL, NIL, NIL, NIL, NIL, {"Revise os parâmetros e o cadastro dos produtos controlados."})
EndIf

FreeObj(oDiag)

FwFreeArray(aSM0)
FwFreeArray(aFiliais)

Return

/*/{Protheus.doc} fValida
Validação dos filtros obrigatórios (fluxo alternativo A1) e montagem da condição de órgãos.
Órgãos cujo campo não existe na SB5 são ignorados no filtro, sem abortar o relatório.
Se nenhuma opção marcada tiver campo na SB5, aborta: a condição vazia equivaleria a
"1 = 1" e o relatório traria todo o estoque sem filtro de órgão.
@type  Static Function
@author bacoetrom@gmail.com
@since  21/10/2026
@param aOrgaos, array, array de órgãos (fOrgaos)
@param cCondOrg, character, retorna a condição SQL dos órgãos (por referência)
@param cErro, character, retorna a mensagem de erro (por referência)
@param cIgnora, character, retorna os órgãos ignorados por falta de campo na SB5 (por referência)
@return logical, .T. se os parâmetros são válidos
/*/
Static Function fValida(aOrgaos, cCondOrg, cErro, cIgnora)

Local cOrg   := fOrgSel()
Local aCond  := {}
Local aNC    := {}
Local cCod   := ""
Local nI     := 0
Local nPos   := 0
Local lRet   := .T.

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
	cErro := "Selecione ao menos um órgão fiscalizador."
EndCase

lRet := Empty(cErro)

//-- Condição SQL dos órgãos marcados (unidos por OR)
For nI := 1 To Len(cOrg) Step ORG_TAM
	If !lRet
		Exit
	EndIf
	cCod := SubStr(cOrg, nI, ORG_TAM)
	If cCod == ORG_NC
		//-- Não controlado: nenhum dos órgãos configurados se aplica ao produto
		For nPos := 1 To Len(aOrgaos)
			If !Empty(aOrgaos[nPos][ORG_CAMPO])
				aAdd(aNC, fCondOrg(aOrgaos[nPos], .F.))
			EndIf
		Next nPos
		If Empty(aNC)
			//-- Sem nenhum campo de órgão não há como saber o que NÃO é controlado:
			//-- "1 = 1" traria todo o estoque como se fosse não controlado
			cErro := "Não há campo de órgão fiscalizador configurado na SB5, então não é " + ;
			         "possível identificar os produtos não controlados."
			lRet  := .F.
		Else
			aAdd(aCond, "(" + fJunta(aNC, " AND ") + ")")
		EndIf
	Else
		nPos := aScan(aOrgaos, {|x| x[ORG_COD] == cCod})
		If nPos == 0
			cErro := "Código de órgão inválido: " + cCod + "."
			lRet  := .F.
		ElseIf Empty(aOrgaos[nPos][ORG_CAMPO])
			//-- Campo inexistente na SB5 (ou parâmetro vazio): o órgão sai do filtro
			If Empty(cIgnora)
				cIgnora := aOrgaos[nPos][ORG_DESC]
			Else
				cIgnora += ", " + aOrgaos[nPos][ORG_DESC]
			EndIf
		Else
			aAdd(aCond, fCondOrg(aOrgaos[nPos], .T.))
		EndIf
	EndIf
Next nI

If lRet
	If Empty(aCond)
		//-- Nenhuma opção marcada tem campo na SB5. Emitir com "1 = 1" traria todo o
		//-- estoque como se fosse controlado, o que é inaceitável num relatório
		//-- regulatório: bloqueia e informa o que falta configurar
		cErro := "Nenhuma das opções marcadas tem campo correspondente na SB5: " + cIgnora + "." + CRLF + ;
		         "Sem isso o relatório listaria todo o estoque sem filtrar por órgão."
		lRet  := .F.
	Else
		cCondOrg := "(" + fJunta(aCond, " OR ") + ")"
	EndIf
EndIf

Return lRet

/*/{Protheus.doc} fProcFil
Processa a filial corrente: produtos com rastro (SB8) e sem rastro (SB2).
/*/
Static Function fProcFil(oReport, oSecao, aOrgaos, cCondOrg, oCfg, oDiag)

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
		oItem   := fMontaItem(cAlias, .T., lSubLote, oMov, cChave, aOrgaos, oCfg, oCache, oDiag)
		If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
			fImprime(oSecao, oItem)
			oDiag["IMPRESSOS"] += 1
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
	oItem  := fMontaItem(cAlias, .F., .F., oMov, cChave, aOrgaos, oCfg, oCache, oDiag)
	If ValType(oItem) $ "O/J"   //-- JsonObject retorna "J"
		fImprime(oSecao, oItem)
		oDiag["IMPRESSOS"] += 1
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
Static Function fMontaItem(cAlias, lLote, lSubLote, oMov, cChave, aOrgaos, oCfg, oCache, oDiag)

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

oItem := JsonObject():New()
oItem["FILIAL"  ] := cFilAnt
oItem["PRODUTO" ] := cProd
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
oItem["ORGAO"   ] := fDescOrg(aOrgaos)
xLimite := fCpoSB5(CPO_LIMEST, Nil)
If ValType(xLimite) == "N" .And. xLimite > 0
	oItem["LIMEST"  ] := xLimite
Else
	oItem["LIMEST"  ] := (cAlias)->EMAX
EndIf
oItem["FDS"     ] := fCpoSB5(CPO_FDS, CPO_VAZIO)
oItem["ARMAZEN" ] := fCpoSB5(CPO_ARMAZ, CPO_VAZIO)
oItem["ARMAZEM" ] := cLocal

If lLote
	oItem["LOTE"    ] := cLote
	oItem["SUBLOTE" ] := If(lSubLote, (cAlias)->SUBLOTE, "")
	oItem["LOTEFOR" ] := (cAlias)->LOTEFOR
	oItem["FABRIC"  ] := fFabric(cProd, cLote, (cAlias)->ORIGLAN, (cAlias)->CLIFOR, (cAlias)->LOJA, oCache)
	oItem["DTFABRIC"] := (cAlias)->DTFABRIC
	oItem["DTVALID" ] := (cAlias)->DTVALID
	oItem["NFDOC"   ] := (cAlias)->DOC
	oItem["NFSERIE" ] := (cAlias)->SERIE
	oItem["NFEMIS"  ] := If(Empty((cAlias)->DOC), CtoD(""), ;
	                     Posicione("SF1", 1, xFilial("SF1") + (cAlias)->DOC + (cAlias)->SERIE + (cAlias)->CLIFOR + (cAlias)->LOJA, "F1_EMISSAO"))
Else
	oItem["LOTE"    ] := ""
	oItem["SUBLOTE" ] := ""
	oItem["LOTEFOR" ] := ""
	oItem["FABRIC"  ] := ""
	oItem["DTFABRIC"] := CtoD("")
	oItem["DTVALID" ] := CtoD("")
	oItem["NFDOC"   ] := ""
	oItem["NFSERIE" ] := ""
	oItem["NFEMIS"  ] := CtoD("")
EndIf

oItem["SLDINI"  ] := nIni
oItem["COMPRAS" ] := aMov[1]
oItem["CONSUMO" ] := aMov[2]
oItem["PERDAS"  ] := aMov[3]
oItem["SLDFIM"  ] := nFim
oItem["SLDSIS"  ] := nSis
oItem["CONFERE" ] := If(Abs(nFim - nSis) < 0.0001, "OK", "DIVERGENTE")
oItem["RESP"    ] := ""
oItem["CONFER"  ] := ""
oItem["OBS"     ] := ""

Return oItem

/*/{Protheus.doc} fImprime
Transfere os valores do item para as células e imprime a linha.
/*/
Static Function fImprime(oSecao, oItem)

Local aCelulas := {"FILIAL", "PRODUTO", "NOMECOM", "NOMEQUI", "CAS", "CODMAPA", "FORMA", "UM", ;
                   "ORGAO", "LIMEST", "FDS", "ARMAZEN", "ARMAZEM", "LOTE", "SUBLOTE", "LOTEFOR", ;
                   "FABRIC", "DTFABRIC", "DTVALID", "NFDOC", "NFSERIE", "NFEMIS", "SLDINI", ;
                   "COMPRAS", "CONSUMO", "PERDAS", "SLDFIM", "SLDSIS", "CONFERE", "RESP", "CONFER", "OBS"}
Local nI       := 0

For nI := 1 To Len(aCelulas)
	oSecao:Cell(aCelulas[nI]):SetValue(oItem[aCelulas[nI]])
Next nI

oSecao:PrintLine()

Return

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
Órgãos fiscalizadores: código, descrição, campo na SB5, parâmetro de origem e regra
(flag = 'S', campo preenchido ou conteúdo igual ao código da lista).
Os 4 primeiros são os órgãos propriamente ditos; em seguida vêm as 12 listas da
Portaria 344/98, todas no mesmo campo (fCampoLis) e diferenciadas pelo conteúdo.
/*/
Static Function fOrgaos()

Local aOrgaos := {}
Local aListas := fListAnv()
Local cCpoLis := fCampoLis()
Local nI      := 0

aAdd(aOrgaos, {"PC", "POLÍCIA CIVIL"  , fCampoMV("MV_MTR947A")      , "MV_MTR947A", .F., ""})
aAdd(aOrgaos, {"PF", "POLÍCIA FEDERAL", fCampoMV("MV_PRODPF")       , "MV_PRODPF" , .F., ""})
aAdd(aOrgaos, {"EX", "EXÉRCITO"       , fCampoMV("MV_MTR949A")      , "MV_MTR949A", .F., ""})
aAdd(aOrgaos, {"AV", "ANVISA"         , fCampoSB5(CPO_ANVISA, .T.)  , ""          , .T., ""})   //-- registro ANVISA: preenchido = controlado

//-- Listas da Portaria SVS/MS 344/98: todas no mesmo campo, diferenciadas pelo conteúdo
For nI := 1 To Len(aListas)
	aAdd(aOrgaos, {aListas[nI][1], aListas[nI][2], cCpoLis, PAR_LISTA, .F., aListas[nI][1]})
Next nI

FwFreeArray(aListas)

Return aOrgaos

/*/{Protheus.doc} fListAnv
Listas de substâncias sujeitas a controle especial da Portaria SVS/MS 344/98
(Anexo I), na ordem em que aparecem na seleção de órgãos.
A3 e B1 compartilham a descrição "PSICOTRÓPICOS" por definição da própria Portaria;
o código exibido ao lado da descrição diferencia as duas opções.
@type  Static Function
@author bacoetrom@gmail.com
@since  05/11/2026
@return array, pares {código de 2 posições, descrição}
/*/
Static Function fListAnv()

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
Nome do campo da SB5 que guarda a lista da Portaria 344/98. Usa o parâmetro
PAR_LISTA quando configurado e, na ausência dele, o campo padrão CPO_LISTA.
Retorna vazio se o campo não existir na SB5 (as listas saem do filtro).
@type  Static Function
@author bacoetrom@gmail.com
@since  05/11/2026
@return character, nome do campo ou vazio
/*/
Static Function fCampoLis()

Local cCampo := Upper(AllTrim(SuperGetMV(PAR_LISTA, .F., CPO_LISTA)))

cCampo := StrTran(cCampo, "SB5->", "")

Return fCampoSB5(cCampo, .T.)

/*/{Protheus.doc} fCondOrg
Condição SQL do órgão: produto controlado (lControla = .T.) ou não controlado (.F.) por ele.
@type  Static Function
@author bacoetrom@gmail.com
@since  21/10/2026
@param aOrg, array, item do array de órgãos (fOrgaos)
@param lControla, logical, .T. condição positiva; .F. condição negada
@return character, condição SQL
/*/
Static Function fCondOrg(aOrg, lControla)

Local cCampo := "COALESCE(SB5." + aOrg[ORG_CAMPO] + ",' ')"
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
Órgãos que controlam o produto posicionado na SB5 (flag = 'S', campo preenchido ou
conteúdo igual ao código da lista da 344/98).
Retorna CPO_VAZIO quando nenhum campo de órgão existe na SB5.
/*/
Static Function fDescOrg(aOrgaos)

Local aDesc     := {}
Local cConteudo := ""
Local cRet      := ""
Local nI        := 0
Local lCampo    := .F.
Local lControla := .F.

For nI := 1 To Len(aOrgaos)
	If !Empty(aOrgaos[nI][ORG_CAMPO])
		lCampo    := .T.
		cConteudo := fCpoSB5(aOrgaos[nI][ORG_CAMPO], "")
		Do Case
		Case !Empty(aOrgaos[nI][ORG_CONTEU])
			lControla := cConteudo == aOrgaos[nI][ORG_CONTEU]
		Case aOrgaos[nI][ORG_PREENCH]
			lControla := !Empty(cConteudo)
		OtherWise
			lControla := cConteudo == "S"
		EndCase
		If lControla
			aAdd(aDesc, aOrgaos[nI][ORG_COD])
		EndIf
	EndIf
Next nI

If !lCampo
	//-- Sem campo de órgão na SB5: não há como classificar o produto
	cRet := CPO_VAZIO
ElseIf Empty(aDesc)
	cRet := "NAO CONTROLADO"
Else
	cRet := fJunta(aDesc, " / ")
EndIf

Return cRet

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
@type  Static Function
@author bacoetrom@gmail.com
@since  21/10/2026
@param cCampo, character, nome do campo
@param lValida, logical, .F. devolve vazio sem consultar a SB5
@return character, nome do campo ou vazio
/*/
Static Function fCampoSB5(cCampo, lValida)

Local aArea := GetArea()

Do Case
Case !lValida .Or. Empty(cCampo)
	cCampo := ""
Case Select("SB5") == 0 .And. !ChkFile("SB5")
	//-- SB5 indisponível no ambiente: não há como validar o campo
	cCampo := ""
Case SB5->(FieldPos(cCampo)) == 0
	cCampo := ""
EndCase

RestArea(aArea)

Return cCampo

/*/{Protheus.doc} fCpoSB5
Conteúdo de um campo da SB5 posicionada; xDefault se o campo não existir.
/*/
Static Function fCpoSB5(cCampo, xDefault)

Local xRet := xDefault
Local nPos := 0

If !Empty(cCampo) .And. Select("SB5") > 0
	nPos := SB5->(FieldPos(cCampo))
	If nPos > 0 .And. !SB5->(Eof())
		xRet := SB5->(FieldGet(nPos))
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

/*/{Protheus.doc} fOrgSel
Códigos dos órgãos marcados na pergunta MV_PAR11, concatenados e sem as posições
não marcadas (ex.: "PF**EX****" -> "PFEX"). Conteúdo inválido digitado na pergunta
é descartado.
@type  Static Function
@author bacoetrom@gmail.com
@since  21/10/2026
@return character, códigos selecionados
/*/
Static Function fOrgSel()

Local aOpcoes  := {}
Local cCodigos := ""
Local cPar     := ""
Local cCod     := ""
Local cRet     := ""
Local nI       := 0

If Type("mv_par" + StrZero(PAR_ORG, 2)) == "C"
	cPar := &("mv_par" + StrZero(PAR_ORG, 2))
EndIf

aOpcoes := fOrgOpc(@cCodigos)

For nI := 1 To Len(cPar) Step ORG_TAM
	cCod := SubStr(cPar, nI, ORG_TAM)
	If fOrgPos(cCod, cCodigos) > 0
		cRet += cCod
	EndIf
Next nI

FwFreeArray(aOpcoes)

Return cRet

/*/{Protheus.doc} fOrgOpc
Opções da seleção múltipla de órgãos fiscalizadores (f_Opcoes), no formato
"XX - DESCRIÇÃO" exigido pela função (código com ORG_TAM posições seguido de " - ").
"Não controlado" é sempre a última opção, pois não é um órgão: existe apenas como
filtro para os produtos que nenhum órgão controla.
@type  Static Function
@author bacoetrom@gmail.com
@since  05/11/2026
@param cCodigos, character, retorna a concatenação dos códigos na ordem das opções (por referência)
@return array, opções exibidas na tela do f_Opcoes
/*/
Static Function fOrgOpc(cCodigos)

Local aOrgaos := fOrgaos()
Local aOpcoes := {}
Local nI      := 0

cCodigos := ""

For nI := 1 To Len(aOrgaos)
	aAdd(aOpcoes, aOrgaos[nI][ORG_COD] + " - " + aOrgaos[nI][ORG_DESC])
	cCodigos += aOrgaos[nI][ORG_COD]
Next nI

aAdd(aOpcoes, ORG_NC + " - NÃO CONTROLADO")
cCodigos += ORG_NC

FwFreeArray(aOrgaos)

Return aOpcoes

/*/{Protheus.doc} fOrgDef
Conteúdo inicial da pergunta MV_PAR11: apenas os órgãos fiscalizadores vêm marcados.
As listas da 344/98 ficam desmarcadas (a opção ANVISA já abrange todos os produtos
controlados pelo órgão) e "não controlado" também, preservando o comportamento
anterior do relatório.
@type  Static Function
@author bacoetrom@gmail.com
@since  05/11/2026
@return character, conteúdo inicial da pergunta
/*/
Static Function fOrgDef()

Local aOrgaos := fOrgaos()
Local cVazio  := Replicate("*", ORG_TAM)
Local cRet    := ""
Local nI      := 0

For nI := 1 To Len(aOrgaos)
	//-- ORG_CONTEU preenchido identifica a sublista, que não vem marcada
	If Empty(aOrgaos[nI][ORG_CONTEU])
		cRet += aOrgaos[nI][ORG_COD]
	Else
		cRet += cVazio
	EndIf
Next nI

//-- "Não controlado" é sempre a última opção (fOrgOpc)
cRet += cVazio

FwFreeArray(aOrgaos)

Return cRet

/*/{Protheus.doc} fOrgPos
Posição do código na lista de códigos válidos, comparando em blocos de ORG_TAM
posições. Retorna 0 para as posições não marcadas ("**") e para códigos inexistentes.
@type  Static Function
@author bacoetrom@gmail.com
@since  05/11/2026
@param cCod, character, código a localizar
@param cCodigos, character, concatenação dos códigos válidos (fOrgOpc)
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

