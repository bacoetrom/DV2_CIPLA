#Include "totvs.ch"

/*/{Protheus.doc} A261TOK
Ponto de Entrada acionado na Transferencia Modelo II (MATA261).
Exige Assinatura Eletronica (Justificativa + Senha do usuario corrente)
antes de confirmar a transferencia, e registra a auditoria de todos os
itens transferidos (aCols) na tabela ZZ2, via classe
ZZ2AssinaEletronica (ver ZZ2U003.tlpp) e U_ZZ2GravaLog (ver
ZZ2U002.tlpp).

@author  Pablo Regis
@since   24/09/2026
@version 1.0
@type    Function
@return  logical, .T. libera a confirmacao da transferencia / .F. cancela
@see     MATA261, ZZ2AssinaEletronica, ZZ2GravaLog
/*/
User Function A261TOK() as Logical

    Local lRet        := .T.         as Logical
    Local lBlind      := IsBlind()   as Logical
    Local cOrigemProc := "1"         as Character // 1 = Manual / Interativo, 2 = Automatico
    Local cDocNum     := cDocumento as Character
    Local oAssinaZZ2  as Object

    If lBlind
        cOrigemProc := "2"
    EndIf

    oAssinaZZ2 := ZZ2AssinaEletronica():New("A261TOK", cDocNum, cOrigemProc)
    oAssinaZZ2:SetItens(aCols)

    If lBlind
        lRet := oAssinaZZ2:GravaAutomatico("TRANSFERENCIA GERADA VIA PROCESSO AUTOMATICO")
        Return lRet
    EndIf

    lRet := oAssinaZZ2:Confirma()

    If !lRet
        Help(NIL, NIL, "VALIDA_TRANSF", NIL, "A transferencia foi cancelada. Justificativa e senha sao obrigatorias.", 1, 0)
    EndIf

Return lRet
