#Include "Protheus.ch"
#Include "FWMVCDef.ch"

/*/{Protheus.doc} CI04A001
Rotina de consulta em MVC da Tabela de Auditoria de Transferencias (ZZ2).
@type function
@author  Desenvolvedor Protheus
@since   22/09/2026
/*/
User Function CI04A001()
    Local oBrowse := FWMBrowse():New()
    
    oBrowse:SetAlias("ZZ2")
    oBrowse:SetDescription("Consulta de Auditoria - Transferencia entre Armazens")
    
    // Adiciona legendas visuais para a Origem do Processo
    oBrowse:AddLegend("ZZ2_ORIGEM == '1'", "GREEN", "Inclusao Manual (Com Senha)")
    oBrowse:AddLegend("ZZ2_ORIGEM == '2'", "BLUE" , "Inclusao Automatica (Job/API)")
    
    oBrowse:Activate()
Return NIL

/*/{Protheus.doc} ViewDef
Construcao do Modelo de Dados (MVC)
@type function
@version 1.0 
@author Pablo Regis
@since 10/6/2026
@return object, modelo
/*/
Static Function ModelDef()
    Local oStruZZ2 := FWFormStruct(1, "ZZ2")
    Local oModel   := MPFormModel():New("CI04A001M")
    
    oModel:AddFields("ZZ2MASTER", NIL, oStruZZ2)
    oModel:SetPrimaryKey({"ZZ2_FILIAL", "ZZ2_DOC", "ZZ2_PRODUT"})
    oModel:SetDescription("Modelo de Dados - Auditoria ZZ2")
    
Return oModel

/*/{Protheus.doc} ViewDef
Construção do MVC
@type function
@version 1.0 
@author Pablo Regis
@since 10/6/2026
@return object, view
/*/
Static Function ViewDef()
    Local oModel   := FWLoadModel("CI04A001")
    Local oStruZZ2 := FWFormStruct(2, "ZZ2")
    Local oView    := FWFormView():New()
    
    oView:SetModel(oModel)
    oView:AddField("VIEW_ZZ2", oStruZZ2, "ZZ2MASTER")
    oView:CreateHorizontalBox("TELA", 100)
    oView:SetOwnerView("VIEW_ZZ2", "TELA")
    
Return oView


/*/{Protheus.doc} MenuDef
Definição do Menu
@type function
@version 1.0 
@author Pablo Regis
@since 10/6/2026
@return array, opções de menu
/*/
Static Function MenuDef()

	Local aRotina := {}

	ADD OPTION aRotina TITLE "Visualizar" ACTION "VIEWDEF.CI04A001" OPERATION 2 ACCESS 0

Return aRotina
