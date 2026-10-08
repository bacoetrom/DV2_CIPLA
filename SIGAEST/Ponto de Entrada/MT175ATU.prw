#Include "totvs.ch"

/*/{Protheus.doc} MT175ATU
Ponto de Entrada acionado na Liberacao/Rejeicao do CQ (MATA175), uma
unica vez apos o OK da tela e antes da gravacao (A175Grava), inclusive
no Estorno (A175Estorna) e no ExecAuto.
Exige Assinatura Eletronica (Justificativa + Senha do usuario corrente)
antes de confirmar o movimento, e registra a auditoria apenas das linhas
novas do aCols (o aCols do MATA175 contem todo o historico do SD7) na
tabela ZZ2, via classe ZZ2AssinaEletronica (ver CI04A003.tlpp) e
U_ZZ2GravaLog (ver CI04A002.tlpp). O tipo do movimento (LIBERACAO,
REJEICAO ou ESTORNO ...) e gravado como prefixo da justificativa.

@author  Pablo Regis
@since   08/10/2026
@version 1.0
@type    Function
@return  logical, .T. libera a gravacao do movimento do CQ / .F. cancela
@see     MATA175, A261TOK, ZZ2AssinaEletronica, ZZ2GravaLog
/*/
User Function MT175ATU() as Logical

    Local lRet        := .T.         as Logical
    Local lAuto       := IsBlind()   as Logical
    Local cOrigemProc := "1"         as Character // 1 = Manual / Interativo, 2 = Automatico
    Local cDocNum     := cA175Num    as Character
    Local aItens      := {}          as Array
    Local oAssinaZZ2  as Object

    If Type("l175Auto") == "L" .And. l175Auto
        lAuto := .T.
    EndIf

    If lAuto
        cOrigemProc := "2"
    EndIf

    aItens := fItensNovos()

    oAssinaZZ2 := ZZ2AssinaEletronica():New("MT175ATU", cDocNum, cOrigemProc)
    oAssinaZZ2:SetTitulo("Assinatura Eletronica - Liberacao/Rejeicao CQ")
    oAssinaZZ2:SetPosicoesGrid(1, 2, 3, 4)
    oAssinaZZ2:SetPosicaoTipo(5)
    oAssinaZZ2:SetItens(aItens)

    If lAuto
        lRet := oAssinaZZ2:GravaAutomatico("LIBERACAO CQ GERADA VIA PROCESSO AUTOMATICO")
        Return lRet
    EndIf

    lRet := oAssinaZZ2:Confirma()

    If !lRet
        Help(NIL, NIL, "VALIDA_CQ", NIL, "A liberacao/rejeicao do CQ foi cancelada. Justificativa e senha sao obrigatorias.", 1, 0)
    EndIf

Return lRet

/*/{Protheus.doc} fItensNovos
Monta o array normalizado apenas com as linhas novas do aCols do MATA175,
usando o mesmo filtro aplicado pelo padrao em A175Grava():
nX > If(lEstorno, 1, nAColsIni) .And. linha nao deletada.
Layout de cada item: {Produto, Quantidade, Armazem Origem (CQ),
Armazem Destino, Tipo do movimento}.

@author  Pablo Regis
@since   08/10/2026
@version 1.0
@type    Function
@return  array, itens novos a serem auditados na ZZ2
/*/
Static Function fItensNovos() as Array

    Local aItens   := {}  as Array
    Local nX       := 0   as Numeric
    Local nIni     := 0   as Numeric
    Local nLenCol  := 0   as Numeric
    Local cTipo    := ""  as Character

    If lEstorno
        nIni := 1
    Else
        nIni := nAColsIni
    EndIf

    For nX := nIni + 1 To Len(aCols)

        nLenCol := Len(aCols[nX])

        If aCols[nX, nLenCol]
            Loop
        EndIf

        cTipo := fDescTipo(aCols[nX, nPosTipo])

        aAdd(aItens, {cA175Prod, aCols[nX, nCQPosQtde], cA175Loc, aCols[nX, nCQPosLDes], cTipo})

    Next nX

Return aItens

/*/{Protheus.doc} fDescTipo
Converte o tipo do movimento do CQ (D7_TIPO: 1 = Liberacao,
2 = Rejeicao) na descricao gravada como prefixo da justificativa na ZZ2.
No Estorno a descricao recebe o prefixo "ESTORNO".

@author  Pablo Regis
@since   08/10/2026
@version 1.0
@type    Function
@param   xTipo, variant, conteudo de D7_TIPO na linha do aCols (numerico ou caracter)
@return  character, descricao do tipo do movimento
/*/
Static Function fDescTipo(xTipo) as Character

    Local cTipo := AllTrim(cValToChar(xTipo)) as Character
    Local cDesc := ""                         as Character

    If cTipo == "1"
        cDesc := "LIBERACAO"
    ElseIf cTipo == "2"
        cDesc := "REJEICAO"
    Else
        cDesc := "TIPO " + cTipo
    EndIf

    If lEstorno
        cDesc := "ESTORNO " + cDesc
    EndIf

Return cDesc
