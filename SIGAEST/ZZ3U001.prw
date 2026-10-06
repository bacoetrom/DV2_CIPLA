#Include "Protheus.ch"
#Include "FWMVCDef.ch"

/*/{Protheus.doc} ZZ3U001
Rotina de consulta em MVC da Tabela de Auditoria de Transferencias (ZZ3).

@author  Desenvolvedor Protheus
@since   22/09/2026
@type    Function
/*/
User Function ZZ3U001()
    Local oBrowse := FWMBrowse():New()
    
    oBrowse:SetAlias("ZZ3")
    oBrowse:SetDescription("Consulta de Auditoria - Transferencia entre Armazens")
    
    // Adiciona legendas visuais para a Origem do Processo
    oBrowse:AddLegend("ZZ3_ORIGEM == '1'", "GREEN", "Inclusao Manual (Com Senha)")
    oBrowse:AddLegend("ZZ3_ORIGEM == '2'", "BLUE" , "Inclusao Automatica (Job/API)")
    
    oBrowse:Activate()
Return NIL

/*/{Protheus.doc} ModelDef
Construcao do Modelo de Dados (MVC)
/*/
Static Function ModelDef()
    Local oStruZZ3 := FWFormStruct(1, "ZZ3")
    Local oModel   := MPFormModel():New("ZZ3U001M")
    
    oModel:AddFields("ZZ3MASTER", NIL, oStruZZ3)
    oModel:SetPrimaryKey({"ZZ3_FILIAL", "ZZ3_DOC", "ZZ3_PRODUT"})
    oModel:SetDescription("Modelo de Dados - Auditoria ZZ3")
    
Return oModel

/*/{Protheus.doc} ViewDef
Construcao da View/Interface Visual (MVC)
/*/
Static Function ViewDef()
    Local oModel   := FWLoadModel("ZZ3U001")
    Local oStruZZ3 := FWFormStruct(2, "ZZ3")
    Local oView    := FWFormView():New()
    
    oView:SetModel(oModel)
    oView:AddField("VIEW_ZZ3", oStruZZ3, "ZZ3MASTER")
    oView:CreateHorizontalBox("TELA", 100)
    oView:SetOwnerView("VIEW_ZZ3", "TELA")
    
Return oView
