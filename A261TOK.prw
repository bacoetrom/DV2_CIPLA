#Include "Protheus.ch"
#Include "Parmtype.ch"

/*/{Protheus.doc} M261TTOK
Ponto de Entrada acionado na Transferencia Modelo II (MATA261).
Valida justificativa e senha do usuario corrente e aciona a gravacao da auditoria.

@author  Desenvolvedor Protheus
@since   22/09/2026
@version 1.0
@type    Function
/*/
User Function A261TOK()
    Local lRet         := .T.
    Local cSenhaInput  := Space(20)
    Local cJustifInput := Space(255)
    Local lConfirmou   := .F.
    Local cUserCod     := RetCodUsr()
    Local cUserName    := UsrRetName(cUserCod)
    Local cOrigemProc  := "1" // 1 = Manual / Interativo, 2 = Automatico
    
    // Variaveis de Interface
    Local oDlg, oGetSenha, oGetJustif, oBtnOk, oBtnCancel
    Local oSay1, oSay2, oSayInfo10 
    // Tratamento para execucao via Job, API ou ExecAuto (sem interface)
    If IsBlind()
        cOrigemProc := "2"
        cJustifInput := "TRANSFERENCIA GERADA VIA PROCESSO AUTOMATICO"
        U_GravaZZ3(cJustifInput, cUserCod, cOrigemProc)
        Return .T.
    EndIf

    // Construcao da Interface Modal de Confirmação
    Define MsDialog oDlg Title "Confirmacao de Seguranca - Transferencia" From 0, 0 To 320, 480 Pixel

        @ 010, 010 Say oSayInfo PROMPT "Usuario: " + AllTrim(cUserName) + " (" + AllTrim(cUserCod) + ")" Size 220, 010 OF oDlg Pixel

        @ 028, 010 Say oSay1 PROMPT "Informe a Justificativa (Obrigatorio):" Size 200, 008 OF oDlg Pixel
        @ 038, 010 Get oGetJustif VAR cJustifInput MEMO Size 220, 040 OF oDlg Pixel

        @ 085, 010 Say oSay2 PROMPT "Redigite sua Senha do Protheus:" Size 200, 008 OF oDlg Pixel
        @ 095, 010 Get oGetSenha VAR cSenhaInput PASSWORD Size 220, 012 OF oDlg Pixel

        @ 125, 110 Button oBtnOk PROMPT "Confirmar" Size 050, 015 ACTION ( ;
            If( ValidarEntradas(cJustifInput, cSenhaInput, cUserName), ;
                (lConfirmou := .T., oDlg:End()), ;
                NIL ;
            ) ;
        ) OF oDlg Pixel

        @ 125, 170 Button oBtnCancel PROMPT "Cancelar" Size 050, 015 ACTION ( ;
            lConfirmou := .F., oDlg:End() ;
        ) OF oDlg Pixel

    Activate MsDialog oDlg Centered

    // Validacao final do Ponto de Entrada
    If !lConfirmou
        Help(NIL, NIL, "VALIDA_TRANSF", NIL, "A transferencia foi cancelada. Justificativa e senha sao obrigatorias.", 1, 0)
        lRet := .F.
    Else
        // Invoca a funcao de gravacao isolada
        U_GravaZZ3(cJustifInput, cUserCod, cOrigemProc)
    EndIf

Return lRet

/*/{Protheus.doc} ValidarEntradas
Valida o preenchimento da justificativa e testa a senha do usuario logado.
/*/
Static Function ValidarEntradas(cJustificativa, cSenha, cUserName)
    If Empty(AllTrim(cJustificativa))
        MsgAlert("A justificativa eh de preenchimento obrigatorio!", "Atencao")
        Return .F.
    EndIf

    If Empty(AllTrim(cSenha))
        MsgAlert("Informe a sua senha de acesso para confirmar a operacao!", "Atencao")
        Return .F.
    EndIf

    // Valida a senha fornecida utilizando a API nativa do Protheus
    If !PswAdmin(AllTrim(cUserName), AllTrim(cSenha))
        MsgStop("Senha invalida! Operacao nao autorizada.", "Erro de Autenticacao")
        Return .F.
    EndIf

Return .T.
